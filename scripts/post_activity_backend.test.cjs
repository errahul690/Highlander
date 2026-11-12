const { test, mock, afterEach } = require('node:test');
const assert = require('node:assert/strict');
const mongoose = require('../../server/node_modules/mongoose');
const Like = require('../../server/src/models/Like');
const User = require('../../server/src/models/User');
const Post = require('../../server/src/models/Post');
const Comment = require('../../server/src/models/PostComment');
const Setting = require('../../server/src/models/AppSetting');
const activity = require('../../server/src/services/common/postActivity.service');
const { postData, postListData } = require('../../server/src/functions/common/posts.functions');
const { setLike } = require('../../server/src/services/user/posts.service');
afterEach(() => mock.restoreAll());
const id = new mongoose.Types.ObjectId();
const userId = new mongoose.Types.ObjectId();
const query = rows => ({ select() { return this; }, sort() { return this; }, skip() { return this; }, limit() { return this; }, lean: async () => rows });
const response = () => ({ set() { return this; }, json(value) { this.body = value; return this; } });
const fail = error => { throw error; };

test('reaction list returns counts, current profiles, and typed filters without exposing emails', async () => {
  let filter;
  mock.method(Like, 'aggregate', async () => [{ _id: 'love', count: 1 }, { _id: 'like', count: 2 }]);
  mock.method(Like, 'find', value => { filter = value; return query([{ created_by: userId, userName: 'Old name', userEmail: 'private', reactionType: 'love' }]); });
  mock.method(User, 'find', () => query([{ _id: userId, full_name: 'Current name', profile_photo: '/new.jpg' }]));
  const res = response();
  await activity.listReactions({ post: { _id: id }, query: { type: 'love' } }, res, fail);
  assert.equal(filter.reactionType, 'love');
  assert.equal(res.body.total, 3);
  assert.equal(res.body.items[0].name, 'Current name');
  assert.equal(res.body.items[0].image, '/new.jpg');
  assert.equal(res.body.items[0].userEmail, undefined);
  assert.equal(res.body.hasMore, false);
});

test('share details only list published reposts and report external activity separately', async () => {
  let filter;
  mock.method(Post, 'countDocuments', async value => { filter = value; return 0; });
  mock.method(Post, 'find', () => query([]));
  const res = response();
  await activity.listShares({ post: { _id: id, shares: 4 }, query: {} }, res, fail);
  assert.equal(filter.status, 'published');
  assert.equal(res.body.total, 4);
  assert.equal(res.body.externalShares, 4);
  assert.deepEqual(res.body.items, []);
});

test('single post and feed preserve reaction type and legacy likes default to like', async () => {
  mock.method(Like, 'countDocuments', async () => 1);
  mock.method(Comment, 'countDocuments', async () => 0);
  mock.method(Post, 'countDocuments', async () => 0);
  mock.method(Like, 'find', () => query([{ postId: id, reactionType: 'wow' }]));
  mock.method(User, 'findById', () => query({ full_name: 'Fan' }));
  mock.method(User, 'find', () => query([{ _id: userId, full_name: 'Fan' }]));
  mock.method(Setting, 'findOne', () => query(null));
  mock.method(Like, 'aggregate', async () => [{ _id: String(id), count: 1 }]);
  mock.method(Comment, 'aggregate', async () => []);
  mock.method(Post, 'aggregate', async () => []);
  const post = { _id: id, created_by: userId };
  assert.equal((await postData(post, { email: 'fan@test.invalid' })).reactionType, 'wow');
  const feed = await postListData([post], { email: 'fan@test.invalid' });
  assert.equal(feed[0].reactionType, 'wow');
  const context = { likes: new Map(), comments: new Map(), reposts: new Map(), liked: new Map([[String(id), {}]]), authors: new Map(), sources: new Map() };
  assert.equal((await postData(post, {}, context)).reactionType, 'like');
});

test('changing a reaction updates the existing per-user like with validation', async () => {
  const stopped = new Error('Stop before notifications');
  let saved;
  mock.method(Like, 'findOneAndUpdate', async (...args) => { saved = args; throw stopped; });
  let error;
  await setLike({ body: { liked: true, reactionType: 'love' }, post: { _id: id }, user: { _id: userId, email: 'fan@test.invalid' } }, response(), value => { error = value; });
  assert.equal(error, stopped);
  assert.deepEqual(saved[0], { postId: id, userEmail: 'fan@test.invalid' });
  assert.deepEqual(saved[1].$set, { reactionType: 'love' });
  assert.equal(saved[2].upsert, true);
  assert.equal(saved[2].runValidators, true);
});

test('unsupported reactions are rejected before any database mutation', async () => {
  const res = response();
  res.status = value => { res.code = value; return res; };
  await setLike({ body: { liked: true, reactionType: 'unknown' } }, res, fail);
  assert.equal(res.code, 400);
  assert.equal(res.body.success, false);
});
