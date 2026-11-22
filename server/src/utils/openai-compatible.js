function joinUrl(baseUrl, path) {
  return `${String(baseUrl).replace(/\/$/, '')}${path}`;
}

export async function chatCompletionRaw({
  apiKey,
  baseUrl,
  model,
  messages,
  tools,
  temperature = 0.6,
  maxTokens = 800,
  extra = {},
  skipThinking = false,
  timeoutMs = 25000,
}) {
  const body = {
    model,
    messages,
    temperature,
    max_tokens: maxTokens,
    stream: false,
    ...extra,
  };
  if (!skipThinking) body.enable_thinking = false;
  if (tools?.length) body.tools = tools;

  const response = await fetch(joinUrl(baseUrl, '/chat/completions'), {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(timeoutMs),
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`LLM 请求失败 (${response.status}): ${text.slice(0, 400)}`);
  }

  const data = await response.json();
  const message = data.choices?.[0]?.message;
  if (!message) throw new Error('LLM 返回内容为空');
  return message;
}

// 流式输出（分类型）：深度思考时，模型先一段段吐思考过程
// （delta.reasoning_content）、再吐正式答案（delta.content）。以前这里
// 只取答案、把思考全丢了，用户在思考期间只能干等一句「思考中…」；
// 现在两种都往外给，由调用方决定怎么展示。事件形状：
// { type: 'reasoning' | 'content', text }。
// 合脑后（2026-11-22）新增工具支持：传 tools 时，模型要调工具会以
// delta.tool_calls 碎片流回来（先给 id 与名字、arguments 一段段续），
// 这里按 index 攒齐，整轮流结束时一次性交出
// { type: 'tool_calls', calls: [{ id, name, arguments }] }，
// 由调用方执行工具再开下一轮。不传 tools 的调用方完全不受影响。
export async function* streamChatEvents({
  apiKey,
  baseUrl,
  model,
  messages,
  tools,
  temperature = 0.6,
  maxTokens = 800,
  extra = {},
  // 流式总超时：默认 40 秒；开了深度思考的调用要传更长（想得久、答得也久），
  // 不放宽会在半路被掐断，用户只看到半句话。
  timeoutMs = 40000,
  // 停滞看门狗：连续多少毫秒收不到任何数据就判定这一路卡死，
  // 抛 code 为 STREAM_STALL 的错给调用方处理。0 = 不启用（旧调用方
  // 不受影响）。总超时管「总共太久」，这个管「中途没动静」——
  // 模型流半路停住时总超时要等很久，看门狗能早点把控制权交回来。
  idleTimeoutMs = 0,
}) {
  const response = await fetch(joinUrl(baseUrl, '/chat/completions'), {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model,
      messages,
      ...(Array.isArray(tools) && tools.length > 0 ? { tools } : {}),
      temperature,
      max_tokens: maxTokens,
      stream: true,
      enable_thinking: false,
      ...extra,
    }),
    signal: AbortSignal.timeout(timeoutMs),
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`LLM 流式请求失败 (${response.status}): ${text.slice(0, 400)}`);
  }

  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buffer = '';
  // 工具调用碎片按 index 攒：同一个调用先到 id 与名字，
  // arguments 随后一段段续上，拼完才是合法 JSON。
  const toolCallSlots = new Map();
  let streamDone = false;

  while (!streamDone) {
    let chunk;
    if (idleTimeoutMs > 0) {
      const readPromise = reader.read();
      readPromise.catch(() => {}); // 看门狗先触发时，防止迟到的读失败变成未处理异常
      let timer = null;
      try {
        chunk = await Promise.race([
          readPromise,
          new Promise((_, reject) => {
            timer = setTimeout(() => {
              const error = new Error(`LLM 流式响应停滞（${Math.round(idleTimeoutMs / 1000)} 秒无数据）`);
              error.code = 'STREAM_STALL';
              reject(error);
            }, idleTimeoutMs);
          }),
        ]);
      } catch (error) {
        try {
          await reader.cancel();
        } catch {
          // 连接可能已经断开，取消失败无所谓
        }
        throw error;
      } finally {
        clearTimeout(timer);
      }
    } else {
      chunk = await reader.read();
    }
    const { done, value } = chunk;
    if (done) break;
    buffer += decoder.decode(value, { stream: true });
    const lines = buffer.split('\n');
    buffer = lines.pop() ?? '';

    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed.startsWith('data: ')) continue;
      const payload = trimmed.slice(6);
      if (payload === '[DONE]') {
        streamDone = true;
        break;
      }
      try {
        const parsed = JSON.parse(payload);
        const delta = parsed.choices?.[0]?.delta;
        const reasoning = delta?.reasoning_content;
        if (reasoning) yield { type: 'reasoning', text: reasoning };
        const content = delta?.content;
        if (content) yield { type: 'content', text: content };
        const fragments = Array.isArray(delta?.tool_calls) ? delta.tool_calls : [];
        for (const fragment of fragments) {
          const index = Number.isInteger(fragment?.index) ? fragment.index : toolCallSlots.size;
          let slot = toolCallSlots.get(index);
          if (!slot) {
            slot = { id: '', name: '', arguments: '' };
            toolCallSlots.set(index, slot);
          }
          if (fragment?.id) slot.id = String(fragment.id);
          if (fragment?.function?.name) slot.name = String(fragment.function.name);
          if (fragment?.function?.arguments) slot.arguments += String(fragment.function.arguments);
        }
      } catch {
        // ignore malformed SSE chunk
      }
    }
  }

  const calls = [...toolCallSlots.values()].filter((call) => call.name);
  if (calls.length > 0) {
    yield { type: 'tool_calls', calls };
  }
}

// 只要答案文本的旧入口（内部转调 streamChatEvents，只挑 content），
// 已有调用方不用改。
export async function* streamChatText(params) {
  for await (const event of streamChatEvents(params)) {
    if (event.type === 'content') yield event.text;
  }
}
