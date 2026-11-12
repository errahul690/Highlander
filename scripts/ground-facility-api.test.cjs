const { test, mock } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { createRequire } = require('node:module');
const root = path.resolve(__dirname, '../../server');
const serverRequire = createRequire(path.join(root, 'package.json'));
serverRequire('dotenv-flow').config({ path: root, silent: true });
const Ground = serverRequire('./src/models/Ground');
const GroundSetting = serverRequire('./src/models/GroundSetting');
const admin = serverRequire('./src/services/admin/grounds.service');
const publicApi = serverRequire('./src/services/public/grounds.service');

test('actual admin save and public API preserve icons and custom upload removal', async () => {
  let stored, payload;
  const response = { status() { return this; }, set() { return this; }, json(value) { payload = value; return this; } };
  const app = { get: () => null };
  mock.method(Ground, 'create', async input => {
    stored = new Ground(input);
    assert.equal(stored.validateSync(), undefined);
    return stored;
  });
  mock.method(Ground, 'findByIdAndUpdate', async (_id, update) => {
    stored = new Ground({ ...stored.toObject(), ...update.$set });
    return stored;
  });
  mock.method(GroundSetting, 'findOne', () => ({ select: () => ({ lean: async () => null }) }));
  mock.method(Ground, 'find', () => ({ select: () => ({ sort: () => ({ lean: async () => [stored.toObject()] }) }) }));
  try {
    await admin.create({ app, body: { name: 'Ground', facility_details: [
      { name: 'Covered seating', icon: 'roof', icon_url: '/uploads/roof.png' },
    ] } }, response);
    assert.equal(payload.facility_details[0].icon, 'roof');
    assert.equal(payload.facility_details[0].icon_url, '/uploads/roof.png');
    await publicApi.list({}, response);
    assert.equal(payload.grounds[0].facility_details[0].icon_url, '/uploads/roof.png');
    assert.deepEqual(payload.grounds[0].facilities, ['Covered seating']);
    await admin.update({ app, params: { id: String(stored._id) }, body: {
      name: 'Ground', facility_details: [{ name: 'Covered seating', icon: 'track', icon_url: '' }],
    } }, response);
    await publicApi.list({}, response);
    assert.equal(payload.grounds[0].facility_details[0].icon, 'track');
    assert.equal(payload.grounds[0].facility_details[0].icon_url, '');
    await assert.rejects(admin.create({ app, body: { name: 'Ground', facility_details: [
      { name: 'Roof', icon: 'roof', icon_url: 'javascript:bad' },
    ] } }, response), /valid uploaded image/);
  } finally { mock.restoreAll(); }
});
