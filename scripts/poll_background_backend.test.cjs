const { test, mock, afterEach } = require('node:test');
const assert = require('node:assert/strict');
const AppSetting = require('../../server/src/models/AppSetting');
const Poll = require('../../server/src/models/Poll');
const { updatePollBackground } = require('../../server/src/services/admin/appSettings.service');
const userPolls = require('../../server/src/services/user/polls.service');
const publicPolls = require('../../server/src/services/public/polls.service');

afterEach(() => mock.restoreAll());
const fail = error => { throw error; };
const response = () => ({ set() { return this; }, status(code) { this.code = code; return this; }, json(body) { this.body = body; } });

test('poll background save and removal persist the global setting and emit a refresh', async () => {
  let saved, event;
  mock.method(AppSetting, 'findOneAndUpdate', async (filter, update, options) => {
    assert.deepEqual(filter, { key: 'mobile-app' });
    assert.equal(options.runValidators, true);
    saved = update.$set.poll_background_image;
    return { poll_background_image: saved };
  });
  const app = { get: () => ({ of: () => ({ to: () => ({ emit: (_name, value) => { event = value; } }) }) }) };
  for (const image of ['/uploads/poll-full-card.png', '']) {
    const res = response();
    await updatePollBackground({ app, body: { poll_background_image: image } }, res, fail);
    assert.equal(saved, image);
    assert.equal(res.body.poll_background_image, image);
    assert.equal(event.resource, 'poll-background');
  }
});

test('invalid poll backgrounds are rejected without a database write', async () => {
  const write = mock.method(AppSetting, 'findOneAndUpdate', () => { throw new Error('Unexpected write'); });
  for (const image of ['javascript:alert(1)', '/uploads/card.svg', '/uploads/../card.png', null, {}]) {
    const res = response();
    await updatePollBackground({ body: { poll_background_image: image } }, res, fail);
    assert.equal(res.code, 400);
  }
  assert.equal(write.mock.callCount(), 0);
});

test('authenticated and public poll responses include the uploaded background', async () => {
  mock.method(AppSetting, 'findOne', () => ({ select: () => ({ lean: async () => ({ poll_background_image: '/uploads/card.webp' }) }) }));
  mock.method(Poll, 'find', () => ({ sort: async () => [{ toPublic: () => ({ _id: 'poll', question: 'Pick a player' }) }] }));
  for (const service of [userPolls, publicPolls]) {
    const res = response();
    await service.list({ user: { _id: 'user' } }, res, fail);
    assert.equal(res.body.poll_background_image, '/uploads/card.webp');
    assert.equal(res.body.polls[0]._id, 'poll');
  }
});
