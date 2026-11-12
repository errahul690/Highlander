const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const React = require('react');
const { renderToStaticMarkup } = require('react-dom/server');
const { transformSync } = require('esbuild');
const source = fs.readFileSync(path.resolve(__dirname, '../../src/components/admin/GroundFacilityEditor.jsx'), 'utf8');
const { code } = transformSync(source, { loader: 'jsx', format: 'cjs', jsx: 'automatic' });
const exported = { exports: {} };
const load = name => name === '@/components/ui/button' ? { Button: props => React.createElement('button', props) }
  : name === '@/components/ui/input' ? { Input: props => React.createElement('input', props) }
  : name === 'lucide-react' ? Object.fromEntries(['Plus', 'Trash2', 'Upload', 'X'].map(key => [key, () => React.createElement('svg')]))
  : require(name);
new Function('require', 'module', 'exports', code)(load, exported, exported.exports);
const { default: Editor, normalizeFacilities } = exported.exports;
const elements = element => !element || typeof element !== 'object' ? []
  : [element, ...React.Children.toArray(element.props?.children).flatMap(elements)];

test('legacy rows and duplicate names retain their distinct configured icons', () => {
  assert.equal(normalizeFacilities(['Roof'])[0].icon, 'auto');
  const details = [{ name: 'Room', icon: 'media' }, { name: 'Room', icon: 'medical' }];
  assert.deepEqual(normalizeFacilities(['Room', 'Room'], details).map(item => item.icon), ['media', 'medical']);
});

test('picker, uploads, preset reset and previews use the configured values', () => {
  let rows = [{ name: 'Covered seats', icon: 'roof', icon_url: '/uploads/roof.png' }];
  const tree = Editor({ value: rows, onChange: change => { rows = change(rows); },
    uploading: '', upload: () => {}, onError: () => {} });
  const html = renderToStaticMarkup(tree);
  assert.match(html, /\/uploads\/roof.png/);
  const dropdown = elements(tree).find(element => element.type === 'select');
  assert.equal(dropdown.props.children.length, 15);
  dropdown.props.onChange({ target: { value: 'track' } });
  assert.equal(rows[0].icon, 'track');
  assert.equal(rows[0].icon_url, '');
});

test('upload validation rejects unsupported files and completion keeps newer row edits', () => {
  let rows = [{ name: 'Covered seats', icon: 'roof', icon_url: '' }];
  let complete, error;
  const tree = Editor({ value: rows, onChange: change => { rows = change(rows); }, uploading: '',
    upload: (_file, done) => { complete = done; }, onError: message => { error = message; } });
  const fileInput = elements(tree).find(element => element.type === 'input' && element.props.type === 'file');
  const choose = file => fileInput.props.onChange({ target: { files: [file], value: 'file' } });
  choose({ type: 'image/svg+xml', size: 10 });
  assert.match(error, /PNG, JPG or WebP/);
  assert.equal(complete, undefined);
  choose({ type: 'image/png', size: 3 * 1024 * 1024 });
  assert.equal(complete, undefined);
  choose({ type: 'image/png', size: 100 });
  rows = [{ ...rows[0], name: 'New seating name' }];
  complete('/uploads/new-icon.png');
  assert.equal(rows[0].name, 'New seating name');
  assert.equal(rows[0].icon_url, '/uploads/new-icon.png');
});
