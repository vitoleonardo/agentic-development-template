import { expect, test } from 'claude-code/testing'

import { barSegments, percentColor, stageRail } from './meters'
import type { Segment } from './meters'

const textOf = (segments: Segment[]) => segments.map(segment => segment.text).join('')
const dotsOf = (segments: Segment[]) => textOf(segments).replace(/[^●◉○]/g, '')

test('COCKPIT-AC24: a bar splits its width in proportion to the parts', () => {
  expect(barSegments(10, [3, 7])).toEqual([3, 7])
  expect(barSegments(20, [2, 1, 3])).toEqual([7, 3, 10])
})

test('COCKPIT-AC24: a bar always fills its width exactly', () => {
  for (const width of [1, 7, 13, 29, 60]) {
    for (const parts of [[1, 1, 1], [2, 5], [1, 0, 6], [5]]) {
      expect(barSegments(width, parts).reduce((sum, count) => sum + count, 0)).toBe(width)
    }
  }
})

test('COCKPIT-AC24: every nonzero part keeps at least one cell while the width allows', () => {
  expect(barSegments(10, [1, 99])).toEqual([1, 9])
  expect(barSegments(10, [98, 1, 1])).toEqual([8, 1, 1])
  expect(barSegments(2, [1, 1, 1]).filter(count => count > 0)).toHaveLength(2)
})

test('COCKPIT-AC24: a bar with no parts left is all the last part, and no width is no cells', () => {
  expect(barSegments(10, [0, 0])).toEqual([0, 10])
  expect(barSegments(0, [1, 2])).toEqual([0, 0])
  expect(barSegments(10, [-3, 2])).toEqual([0, 10])
})

test('COCKPIT-AC24: the stage rail marks finished, current and coming stages', () => {
  const { rail } = stageRail('build', 60)

  expect(textOf(rail)).toHaveLength(60)
  expect(dotsOf(rail)).toBe('●●◉○○○○')
  expect(rail.find(segment => segment.text.includes('◉'))?.color).toBe('claude')
  const colorsOf = (dot: string) => rail.filter(segment => segment.text.includes(dot)).map(segment => segment.color)
  expect(colorsOf('●')).toEqual(['success'])
  expect(colorsOf('○')).toEqual(['subtle'])
})

test('COCKPIT-AC24: the stage rail labels sit under their dots, the current one bold', () => {
  const { rail, labels } = stageRail('review', 60)
  const railText = textOf(rail)
  const labelText = textOf(labels)

  expect(labelText).toHaveLength(60)
  expect(labelText.trim().split(/\s+/)).toEqual(['spec', 'plan', 'build', 'review', 'verify', 'pr', 'done'])
  const current = railText.indexOf('◉')
  const reviewStart = labelText.indexOf('review')
  expect(current).toBeGreaterThanOrEqual(reviewStart)
  expect(current).toBeLessThan(reviewStart + 'review'.length)
  expect(labels.find(segment => segment.text.includes('review'))).toEqual({
    text: 'review',
    color: 'claude',
    isBold: true,
  })
})

test('COCKPIT-AC24: below 50 columns the stage rail has no labels', () => {
  const { rail, labels } = stageRail('plan', 49)

  expect(textOf(rail)).toHaveLength(49)
  expect(labels).toEqual([])
})

test('COCKPIT-AC24: a done feature fills every dot of the rail', () => {
  expect(dotsOf(stageRail('done', 60).rail)).toBe('●●●●●●●')
})

test('COCKPIT-AC24: the budget color turns warning at 80 % and error at 100 %', () => {
  expect(percentColor(42)).toBe('success')
  expect(percentColor(79)).toBe('success')
  expect(percentColor(80)).toBe('warning')
  expect(percentColor(99)).toBe('warning')
  expect(percentColor(100)).toBe('error')
  expect(percentColor(115)).toBe('error')
})
