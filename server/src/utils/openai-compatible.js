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

export async function* streamChatText({
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
        const content = parsed.choices?.[0]?.delta?.content;
        if (content) yield content;
      } catch {
        // ignore malformed SSE chunk
      }
    }
  }
}
