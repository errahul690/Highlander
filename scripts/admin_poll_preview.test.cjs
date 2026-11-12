const { test, mock, afterEach } = require('node:test');
const assert = require('node:assert/strict');
const IntegrationService = require('../../server/src/services/integration.service');
const preview = require('../../server/src/services/admin/pollBackgroundPreview.service');

afterEach(() => mock.restoreAll());
const fail = error => { throw error; };
const response = () => ({
  headers: {}, status(code) { this.code = code; return this; },
  json(body) { this.body = body; return this; },
  set(key, value) { this.headers[key] = value; return this; },
  type(value) { this.contentType = value; return this; },
  send(value) { this.body = value; return this; },
});

test('admin preview returns image bytes without a cross-origin redirect', async () => {
  const bytes = Buffer.from([137, 80, 78, 71, 1, 2, 3]);
  mock.method(IntegrationService, 'mediaUrl', async key => {
    assert.equal(key, 'uploads/poll.png'); return 'https://storage.example.test/poll.png';
  });
  mock.method(globalThis, 'fetch', async () => new Response(bytes));
  const res = response();
  await preview({ query: { image: '/uploads/poll.png' } }, res, fail);
  assert.deepEqual(res.body, bytes);
  assert.equal(res.contentType, 'png');
  assert.equal(res.headers['Cache-Control'], 'private, no-store');
});

test('admin preview rejects arbitrary URLs and traversal before fetching', async () => {
  const fetch = mock.method(globalThis, 'fetch', () => { throw new Error('Unexpected fetch'); });
  for (const image of ['https://example.test/private', '/uploads/../private.png', '/uploads/script.svg', null]) {
    const res = response();
    await preview({ query: { image } }, res, fail);
    assert.equal(res.code, 400);
  }
  assert.equal(fetch.mock.callCount(), 0);
});

test('admin preview reports unavailable and oversized artwork', async () => {
  mock.method(IntegrationService, 'mediaUrl', async () => 'https://storage.example.test/poll.png');
  const fetch = mock.method(globalThis, 'fetch', async () => new Response(null, { status: 404 }));
  let res = response();
  await preview({ query: { image: '/uploads/poll.png' } }, res, fail);
  assert.equal(res.code, 502);
  fetch.mock.mockImplementation(async () => new Response(Buffer.alloc(15 * 1024 * 1024 + 1)));
  res = response();
  await preview({ query: { image: '/uploads/poll.png' } }, res, fail);
  assert.equal(res.code, 413);
});
