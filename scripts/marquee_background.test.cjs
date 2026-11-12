const { test } = require('node:test');
const assert = require('node:assert/strict');
const { validateMarquee } = require('../../server/src/functions/common/appSettings.functions');
const AppSetting = require('../../server/src/models/AppSetting');

test('marquee accepts and persists the admin background while partial updates preserve defaults', () => {
  const item = validateMarquee({ text: 'Club news', background_color: '#102030' });
  assert.equal(item.background_color, '#102030');
  const setting = new AppSetting({ key: 'color-test', marquee: item });
  assert.equal(setting.toObject().marquee.background_color, '#102030');
  assert.equal(new AppSetting({ key: 'legacy', marquee: { text: 'News' } }).marquee.background_color, '#FBF0F0');
  assert.equal(Object.hasOwn(validateMarquee({ text: 'News' }), 'background_color'), false);
  for (const background_color of ['red', '#123', '#12345678', null, 123]) {
    assert.throws(() => validateMarquee({ text: 'News', background_color }), /background color/);
  }
});
