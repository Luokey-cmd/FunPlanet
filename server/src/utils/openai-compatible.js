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
export async function* streamChatEvents({
  apiKey,
  baseUrl,
  model,
  messages,
  temperature = 0.6,
  maxTokens = 800,
  extra = {},
  // 流式总超时：默认 40 秒；开了深度思考的调用要传更长（想得久、答得也久），
  // 不放宽会在半路被掐断，用户只看到半句话。
  timeoutMs = 40000,
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

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });
    const lines = buffer.split('\n');
    buffer = lines.pop() ?? '';

    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed.startsWith('data: ')) continue;
      const payload = trimmed.slice(6);
      if (payload === '[DONE]') return;
      try {
        const parsed = JSON.parse(payload);
        const delta = parsed.choices?.[0]?.delta;
        const reasoning = delta?.reasoning_content;
        if (reasoning) yield { type: 'reasoning', text: reasoning };
        const content = delta?.content;
        if (content) yield { type: 'content', text: content };
      } catch {
        // ignore malformed SSE chunk
      }
    }
  }
}

// 只要答案文本的旧入口（内部转调 streamChatEvents，只挑 content），
// 已有调用方不用改。
export async function* streamChatText(params) {
  for await (const event of streamChatEvents(params)) {
    if (event.type === 'content') yield event.text;
  }
}
