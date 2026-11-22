// 语音流式识别中转：App ←WebSocket→ 本服务 ←WebSocket→ 通义实时识别。
//
// 为什么要中转：实时识别（qwen3-asr-flash-realtime）要长连接、且要用
// DASHSCOPE_API_KEY 鉴权，密钥绝不能放进 App，所以 App 只连自家服务，
// 由本服务代连通义。顺便把通义那套较繁的事件协议翻译成 App 听得懂的
// 四种小消息：ready（可以说话了）、partial（识别中的全文，会被修正）、
// final（一句说完后的定稿全文）、done（全部结束）、error（出错）。
//
// App 侧协议（路径 /api/voice/stream，握手带 Authorization: Bearer 登录令牌）：
//   App → 服务端：二进制帧 = PCM 原始音频片（16kHz 单声道 16bit）；
//                 文本帧 {"type":"stop"} = 用户点停，去拿最后定稿。
//   服务端 → App：上面五种 JSON 文本消息。partial/final 的 text 都是
//                 「当前这一句」的文字（与输入栏既有的 onResult 口径
//                 一致：中间结果整段替换本句、定稿后由输入栏并入底子），
//                 所以服务端不跨句累计，通义给什么就转什么。
//
// 坑：通义 VAD 模式下，结束时必须先发 session.finish 并等它把最后一句
//     的 completed 吐回来，直接断连会把没说完的半句丢掉。
// 兜底：本服务任何异常都给 App 回 error 或直接断开，App 会自动回落到
//     原来的整段识别/系统弹窗路线，不会让语音功能整体不可用。

import { WebSocket, WebSocketServer } from 'ws';
import { verifyToken } from './jwt.js';

const STREAM_PATH = '/api/voice/stream';
const MAX_SESSION_MS = 90 * 1000; // 单次流式会话上限，防忘关占连接
let eventSeq = 0;

function nextEventId() {
  eventSeq += 1;
  return `evt_${Date.now()}_${eventSeq}`;
}

function sendJson(ws, payload) {
  if (ws && ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify(payload));
  }
}

// 通义实时识别的会话配置：VAD 自动断句（停顿 1000ms 算一句完）、中文、
// PCM 16k 输入。partial 结果由 .text 事件实时下发。
// 断句时长别再调回 400ms：真机实测（2026-11-21）人说话的自然停顿
// 普遍超过 400ms，会被切成好几段、每段还被识别服务补一个句号，
// 一句话变成「我在。深圳呀。嗯。」；1000ms 下说完后约 1 秒定稿，可接受。
function buildSessionUpdate() {
  return {
    event_id: nextEventId(),
    type: 'session.update',
    session: {
      modalities: ['text'],
      input_audio_format: 'pcm',
      sample_rate: 16000,
      input_audio_transcription: { language: 'zh' },
      turn_detection: { type: 'server_vad', threshold: 0.2, silence_duration_ms: 1000 },
    },
  };
}

// 定稿下发前剥掉段末句号：断句把一段话切成几段时，识别服务会给每段
// 自动补「。」，原样拼进输入框就一句一个句号。这里只剥句号，问号、
// 感叹号带语气、保留不动；聊天输入末尾没有句号也完全自然。
export function stripFinalPeriod(text) {
  return String(text ?? '').replace(/。+$/, '');
}

// 一次 App 连接 = 一次识别会话。状态都收在本闭包里，连接结束即释放。
function startRelaySession(appWs) {
  const apiKey = process.env.DASHSCOPE_API_KEY;
  if (!apiKey) {
    sendJson(appWs, { type: 'error', message: '服务端未配置语音识别' });
    appWs.close();
    return;
  }

  const model = process.env.QWEN_ASR_STREAM_MODEL || 'qwen3-asr-flash-realtime';
  // 上游地址可配（百炼新业务空间域名或自测打桩都走这个变量），默认官方域名。
  const base = process.env.DASHSCOPE_REALTIME_WS_URL || 'wss://dashscope.aliyuncs.com/api-ws/v1/realtime';
  const upstream = new WebSocket(
    `${base}?model=${encodeURIComponent(model)}`,
    { headers: { Authorization: `Bearer ${apiKey}`, 'OpenAI-Beta': 'realtime=v1' } },
  );

  let finishSent = false; // session.finish 只发一次
  let settled = false; // 会话已收尾，避免两边 close 互相触发重复处理
  const maxTimer = setTimeout(() => finishSession(), MAX_SESSION_MS);

  function sendFinish() {
    if (finishSent) return;
    finishSent = true;
    if (upstream.readyState === WebSocket.OPEN) {
      upstream.send(JSON.stringify({ event_id: nextEventId(), type: 'session.finish' }));
    }
  }

  // 收尾：通知 App 结束，关掉两边连接。reason 有值表示异常结束。
  function settle(reason) {
    if (settled) return;
    settled = true;
    clearTimeout(maxTimer);
    if (reason) {
      sendJson(appWs, { type: 'error', message: reason });
    } else {
      sendJson(appWs, { type: 'done' });
    }
    try {
      upstream.close();
    } catch {}
    try {
      appWs.close();
    } catch {}
  }

  function finishSession() {
    // 正常结束：先让通义把最后一句定稿吐回来，等 session.finished 再收尾；
    // 上游已经断了就直接收尾，别让 App 干等。
    if (upstream.readyState === WebSocket.OPEN) {
      sendFinish();
      setTimeout(() => settle(null), 3000).unref?.();
    } else {
      settle(null);
    }
  }

  upstream.on('open', () => {
    upstream.send(JSON.stringify(buildSessionUpdate()));
  });

  upstream.on('message', (data) => {
    let event;
    try {
      event = JSON.parse(data.toString());
    } catch {
      return;
    }
    switch (event?.type) {
      case 'session.updated':
        sendJson(appWs, { type: 'ready' });
        break;
      case 'conversation.item.input_audio_transcription.text': {
        // text 是已稳住的部分，stash 是还在变的部分，拼起来是当前这句。
        const partial = `${event.text ?? ''}${event.stash ?? ''}`;
        sendJson(appWs, { type: 'partial', text: partial });
        break;
      }
      case 'conversation.item.input_audio_transcription.completed': {
        // 这一句的定稿，只发本句（跨句累计由输入栏的底子机制负责）。
        sendJson(appWs, { type: 'final', text: stripFinalPeriod(event.transcript) });
        break;
      }
      case 'session.finished':
        settle(null);
        break;
      case 'error':
        console.warn('[voice-stream] dashscope error:', JSON.stringify(event.error ?? event).slice(0, 300));
        settle('语音识别服务暂时不可用');
        break;
      default:
        break; // speech_started/stopped、committed 等事件 App 不关心，忽略
    }
  });

  upstream.on('error', (error) => {
    console.warn('[voice-stream] upstream error:', error.message);
    settle('语音识别服务连接失败');
  });

  upstream.on('close', () => {
    // 上游先断（如密钥失效握手失败）：还没收尾就按异常结束通知 App。
    if (!settled) settle('语音识别服务连接中断');
  });

  appWs.on('message', (data, isBinary) => {
    if (isBinary) {
      // 音频片：转成通义要的 append 事件（二进制内容转 base64）。
      if (upstream.readyState === WebSocket.OPEN) {
        upstream.send(
          JSON.stringify({
            event_id: nextEventId(),
            type: 'input_audio_buffer.append',
            audio: Buffer.from(data).toString('base64'),
          }),
        );
      }
      return;
    }
    let control;
    try {
      control = JSON.parse(data.toString());
    } catch {
      return;
    }
    if (control?.type === 'stop') finishSession();
  });

  appWs.on('close', () => {
    // App 主动断开（页面关了等）：尽力让上游正常 finish 后各自关闭。
    if (!settled) {
      sendFinish();
      setTimeout(() => settle(null), 500).unref?.();
    }
  });

  appWs.on('error', () => {
    if (!settled) settle(null);
  });
}

// 把流式语音挂到与 HTTP 接口同一个服务上（同一个端口，靠路径区分）。
// 输入：index.js 里 app.listen 返回的 http.Server。
// 只有路径与登录令牌都对的升级请求才接，其余连接直接拒掉。
export function attachVoiceStreamServer(httpServer) {
  const wss = new WebSocketServer({ noServer: true });

  httpServer.on('upgrade', (req, socket, head) => {
    let pathname = '';
    try {
      pathname = new URL(req.url ?? '', 'http://localhost').pathname;
    } catch {
      pathname = '';
    }
    if (pathname !== STREAM_PATH) {
      socket.destroy();
      return;
    }
    const header = req.headers.authorization || '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : null;
    let authed = false;
    if (token) {
      try {
        verifyToken(token);
        authed = true;
      } catch {
        authed = false;
      }
    }
    if (!authed) {
      socket.write('HTTP/1.1 401 Unauthorized\r\nConnection: close\r\n\r\n');
      socket.destroy();
      return;
    }
    wss.handleUpgrade(req, socket, head, (ws) => {
      wss.emit('connection', ws, req);
    });
  });

  wss.on('connection', (appWs) => {
    startRelaySession(appWs);
  });

  console.log('语音流式识别已挂载: /api/voice/stream');
}
