// Correct font style metadata only; glyph outlines and spacing remain intact.
// The supplied exports label multiple distinct Gilroy faces as weight 400.
const fs = require('node:fs');
const path = require('node:path');
const weights = { Thin: 100, UltraLight: 200, Light: 300, Regular: 400,
  Medium: 500, SemiBold: 600, Bold: 700, ExtraBold: 800, Black: 900, Heavy: 900 };
const directory = path.resolve(__dirname, '../assets/fonts');

function checksum(bytes, offset, length) {
  let sum = 0;
  for (let i = 0; i < length; i += 4) {
    let value = 0;
    for (let j = 0; j < 4; j++) value = value * 256 + (i + j < length ? bytes[offset + i + j] : 0);
    sum = (sum + value) >>> 0;
  }
  return sum;
}

for (const [face, weight] of Object.entries(weights)) {
  for (const italic of [false, true]) {
    const filename = `Gilroy-${face}${italic ? 'Italic' : ''}.ttf`;
    const file = path.join(directory, filename);
    const bytes = fs.readFileSync(file);
    const tables = {};
    for (let i = 0; i < bytes.readUInt16BE(4); i++) {
      const entry = 12 + i * 16;
      tables[bytes.toString('ascii', entry, entry + 4)] = {
        entry, offset: bytes.readUInt32BE(entry + 8), length: bytes.readUInt32BE(entry + 12),
      };
    }
    const os2 = tables['OS/2'].offset;
    const head = tables.head.offset;
    const previous = bytes.readUInt16BE(os2 + 4);
    bytes.writeUInt16BE(weight, os2 + 4);
    // fsSelection: italic, bold, regular. Preserve unrelated flags.
    let selection = bytes.readUInt16BE(os2 + 62) & ~0x61;
    if (italic) selection |= 1;
    if (weight >= 700) selection |= 0x20;
    if (weight === 400 && !italic) selection |= 0x40;
    bytes.writeUInt16BE(selection, os2 + 62);
    let style = bytes.readUInt16BE(head + 44) & ~3;
    if (weight >= 700) style |= 1;
    if (italic) style |= 2;
    bytes.writeUInt16BE(style, head + 44);
    bytes.writeUInt32BE(0, head + 8);
    for (const table of Object.values(tables)) {
      bytes.writeUInt32BE(checksum(bytes, table.offset, table.length), table.entry + 4);
    }
    bytes.writeUInt32BE((0xB1B0AFBA - checksum(bytes, 0, bytes.length)) >>> 0, head + 8);
    if (checksum(bytes, 0, bytes.length) !== 0xB1B0AFBA) throw new Error(`Checksum failed: ${filename}`);
    fs.writeFileSync(file, bytes);
    console.log(`${filename}: ${previous} -> ${weight}`);
  }
}
