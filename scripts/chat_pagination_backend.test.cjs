const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

// Exercise the shared history query used by both authenticated routes.
const source = fs.readFileSync(path.resolve(__dirname, '../../server/src/routes/community.routes.js'), 'utf8');
const helper = source.slice(source.indexOf('async function messageHistory('), source.indexOf("router.get('/direct/messages',"));
function fixture() {
  const calls = [];
  const context = {
    Message: { find(filter) {
      const call = { filter };
      calls.push(call);
      return { sort(order) {
        call.order = order;
        return { limit(limit) {
          call.limit = limit;
          return { lean: async () => [{ _id: 'newer' }, { _id: 'older' }] };
        } };
      } };
    } },
    fail(message, status) { throw Object.assign(new Error(message), { status }); },
  };
  vm.createContext(context);
  vm.runInContext(helper + '\nthis.history = messageHistory;', context);
  return { calls, history: context.history };
}

test('history limits database reads and retains the legacy chronological array response', async () => {
  const { history, calls } = fixture();
  const scope = { conversationId: 'room' };
  const rows = await history({ query: { limit: '21' } }, scope);
  assert.equal(calls[0].limit, 21);
  assert.equal(calls[0].filter, scope);
  assert.equal(calls[0].order, '-createdAt -_id');
  assert.deepEqual(Array.from(rows, row => row._id), ['older', 'newer']);
  await history({ query: {} }, scope);
  assert.equal(calls[1].limit, 100);
});

test('cursor preserves the full authorization scope and breaks timestamp ties by ID', async () => {
  const { history, calls } = fixture();
  const scope = { hiddenFor: { $ne: 'me' }, $or: [{ senderEmail: 'me' }, { receiverEmail: 'me' }] };
  const before = '2026-11-12T10:00:00.000Z';
  const beforeId = '000000000000000000000026';
  await history({ query: { limit: '21', before, beforeId } }, scope);
  const filter = calls[0].filter;
  assert.equal(filter.$and[0], scope);
  assert.deepEqual(JSON.parse(JSON.stringify(filter.$and[1])), { $or: [
    { createdAt: { $lt: before } },
    { createdAt: before, _id: { $lt: beforeId } },
  ] });
});

test('invalid limits and malformed cursors are rejected before querying messages', async () => {
  const { history, calls } = fixture();
  for (const query of [
    { limit: '0' }, { limit: '101' }, { limit: '1.5' }, { limit: 'NaN' },
    { before: 'invalid', beforeId: '000000000000000000000001' },
    { before: '2026-11-12', beforeId: { $ne: '' } },
    { beforeId: '000000000000000000000001' },
    { before: '2026-11-12' },
  ]) {
    await assert.rejects(history({ query }, {}), error => error.status === 400);
  }
  assert.equal(calls.length, 0);
});
