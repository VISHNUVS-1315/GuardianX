const http = require('http');
const { randomUUID } = require('crypto');

const PORT = Number(process.env.PORT || 10000);
const SERVICE_NAME = 'guardianx-api';
const STARTED_AT = new Date().toISOString();
const MAX_BODY_BYTES = 32 * 1024;

function sendJson(res, statusCode, payload) {
  const body = JSON.stringify(payload);
  res.writeHead(statusCode, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(body),
    'Cache-Control': 'no-store',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, X-GuardianX-Client',
  });
  res.end(body);
}

function readJson(req) {
  return new Promise((resolve, reject) => {
    let size = 0;
    const chunks = [];

    req.on('data', (chunk) => {
      size += chunk.length;
      if (size > MAX_BODY_BYTES) {
        reject(Object.assign(new Error('Payload too large'), { statusCode: 413 }));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });

    req.on('end', () => {
      if (chunks.length === 0) {
        resolve({});
        return;
      }
      try {
        resolve(JSON.parse(Buffer.concat(chunks).toString('utf8')));
      } catch {
        reject(Object.assign(new Error('Invalid JSON body'), { statusCode: 400 }));
      }
    });

    req.on('error', reject);
  });
}

function validNumber(value) {
  return typeof value === 'number' && Number.isFinite(value);
}

function validateIncident(body) {
  const allowedTypes = new Set(['sos', 'possible_crash', 'manual_help']);
  if (!allowedTypes.has(body.type)) return 'Unsupported incident type.';

  if (!body.location || typeof body.location !== 'object') {
    return 'location is required.';
  }

  const { latitude, longitude, accuracy } = body.location;
  if (!validNumber(latitude) || latitude < -90 || latitude > 90) {
    return 'Invalid latitude.';
  }
  if (!validNumber(longitude) || longitude < -180 || longitude > 180) {
    return 'Invalid longitude.';
  }
  if (accuracy != null && (!validNumber(accuracy) || accuracy < 0 || accuracy > 100000)) {
    return 'Invalid accuracy.';
  }

  if (body.shareUrl != null) {
    if (typeof body.shareUrl !== 'string' || body.shareUrl.length > 2048) {
      return 'Invalid shareUrl.';
    }
    if (body.shareUrl && !/^https:\/\//i.test(body.shareUrl)) {
      return 'shareUrl must use https.';
    }
  }

  return null;
}

const server = http.createServer(async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, X-GuardianX-Client',
      'Access-Control-Max-Age': '86400',
    });
    res.end();
    return;
  }

  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);

  if (req.method === 'GET' && (url.pathname === '/' || url.pathname === '/health')) {
    sendJson(res, 200, {
      ok: true,
      service: SERVICE_NAME,
      status: 'live',
      version: '1.0.0',
      regionHint: process.env.RENDER_REGION || null,
      startedAt: STARTED_AT,
      serverTime: new Date().toISOString(),
    });
    return;
  }

  if (req.method === 'GET' && url.pathname === '/api/status') {
    sendJson(res, 200, {
      ok: true,
      service: SERVICE_NAME,
      capabilities: {
        incidentIntake: true,
        firebaseRealtimeTracking: 'client-managed',
        emergencyNumberIndia: '112',
      },
      note: 'GuardianX API acknowledges safety events. It is not an emergency dispatch service.',
      serverTime: new Date().toISOString(),
    });
    return;
  }

  if (req.method === 'POST' && url.pathname === '/api/incidents') {
    try {
      const body = await readJson(req);
      const validationError = validateIncident(body);
      if (validationError) {
        sendJson(res, 400, { ok: false, error: validationError });
        return;
      }

      const incidentId = randomUUID();
      console.log(JSON.stringify({
        event: 'incident_received',
        incidentId,
        type: body.type,
        receivedAt: new Date().toISOString(),
        hasShareUrl: Boolean(body.shareUrl),
        accuracy: body.location.accuracy ?? null,
      }));

      sendJson(res, 202, {
        ok: true,
        accepted: true,
        incidentId,
        receivedAt: new Date().toISOString(),
        nextActions: {
          keepLiveTrackingActive: true,
          contactTrustedGuardian: true,
          emergencyNumberIndia: '112',
        },
        warning: 'GuardianX API is a support service and does not automatically dispatch emergency responders.',
      });
    } catch (error) {
      sendJson(res, error.statusCode || 500, {
        ok: false,
        error: error.statusCode ? error.message : 'Internal server error',
      });
    }
    return;
  }

  sendJson(res, 404, { ok: false, error: 'Not found' });
});

server.requestTimeout = 10_000;
server.headersTimeout = 12_000;
server.keepAliveTimeout = 5_000;

server.listen(PORT, '0.0.0.0', () => {
  console.log(`${SERVICE_NAME} listening on port ${PORT}`);
});

function shutdown(signal) {
  console.log(`${signal} received; shutting down ${SERVICE_NAME}`);
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(1), 5000).unref();
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
