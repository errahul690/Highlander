const { test } = require('node:test');
const assert = require('node:assert/strict');
const { pathToFileURL } = require('node:url');
const path = require('node:path');
const statsModule = import(pathToFileURL(path.resolve(__dirname, '../../src/lib/matchReportStats.js')).href);
const { KnockoutMatch } = require('../../server/src/models/KnockoutMatch');

test('shots on target save both teams, including zero, using the existing match schema', async () => {
  const { reportMetrics, updateReportStat } = await statsModule;
  const metric = reportMetrics.find(metric => metric.label === 'Shots on Target');
  let details = updateReportStat({}, metric, 'home', '6');
  details = updateReportStat(details, metric, 'away', '0');
  assert.deepEqual(details.stats, [{ label: 'Shots on Target', home: '6', away: '0' }]);
  const match = new KnockoutMatch({ match_details: details, report_thumbnail: '/uploads/report-background.png' });
  assert.equal(match.validateSync(), undefined);
  assert.equal(match.toObject().match_details.stats[0].away, '0');
  assert.equal(match.toObject().report_thumbnail, '/uploads/report-background.png');
});

test('editing imported target shots preserves lineups and unrelated statistics', async () => {
  const { reportMetrics, updateReportStat, reportStat } = await statsModule;
  const metric = reportMetrics[1];
  const details = { home_lineup: [{ name: 'Player' }], stats: [
    { label: 'On target shots', home: '6', away: '2' },
    { label: 'Corners', home: '5', away: '3' },
  ] };
  const updated = updateReportStat(details, metric, 'away', '4');
  assert.equal(reportStat(updated, metric).home, '6');
  assert.equal(reportStat(updated, metric).away, '4');
  assert.equal(updated.stats.length, 2);
  assert.deepEqual(updated.home_lineup, details.home_lineup);
  assert.deepEqual(updated.stats[0], details.stats[1]);
  assert.equal(details.stats[0].away, '2');
});

test('blank statistics stay unknown, clear correctly and reject invalid values', async () => {
  const { reportMetrics, updateReportStat } = await statsModule;
  const shots = reportMetrics[0], possession = reportMetrics[2];
  assert.deepEqual(updateReportStat({}, shots, 'home', '').stats, []);
  let details = updateReportStat({}, shots, 'home', '2');
  details = updateReportStat(details, shots, 'home', '');
  assert.deepEqual(details.stats, []);
  for (const value of ['-1', '2.5', 'NaN']) assert.equal(updateReportStat(details, shots, 'home', value), details);
  assert.equal(updateReportStat(details, possession, 'home', '101'), details);
  assert.equal(updateReportStat(details, possession, 'home', '58.5').stats[0].home, '58.5');
});

test('possession calculates the opposite team from either field and clears the pair', async () => {
  const { reportMetrics, updateReportStat, reportStat } = await statsModule;
  const metric = reportMetrics.find(metric => metric.percent);
  let details = updateReportStat({}, metric, 'home', '58.5');
  assert.deepEqual(reportStat(details, metric), { label: 'Possession', home: '58.5', away: '41.5' });
  details = updateReportStat(details, metric, 'away', '40');
  assert.deepEqual(reportStat(details, metric), { label: 'Possession', home: '60', away: '40' });
  details = updateReportStat(details, metric, 'home', '0');
  assert.equal(reportStat(details, metric).away, '100');
  details = updateReportStat(details, metric, 'away', '0');
  assert.equal(reportStat(details, metric).home, '100');
  details = updateReportStat(details, metric, 'home', '58.1');
  assert.equal(reportStat(details, metric).away, '41.9');
  assert.equal(updateReportStat(details, metric, 'away', '100.1'), details);
  details = updateReportStat(details, metric, 'away', '');
  assert.equal(reportStat(details, metric), undefined);
});
