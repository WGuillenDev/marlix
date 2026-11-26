const TIME_ZONE = 'America/Costa_Rica';

const dateFormat = new Intl.DateTimeFormat('en-CA', {
  timeZone: TIME_ZONE,
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
});

const wallClockFormat = new Intl.DateTimeFormat('en-US', {
  timeZone: TIME_ZONE,
  hourCycle: 'h23',
  year: 'numeric',
  month: 'numeric',
  day: 'numeric',
  hour: 'numeric',
  minute: 'numeric',
  second: 'numeric',
});

export function costaRicaDay(now: Date): string {
  return dateFormat.format(now);
}

function offsetAt(instant: number): number {
  const parts = Object.fromEntries(
    wallClockFormat.formatToParts(instant).map(({ type, value }) => [type, Number(value)]),
  );
  const wallClock = Date.UTC(
    parts.year!,
    parts.month! - 1,
    parts.day!,
    parts.hour!,
    parts.minute!,
    parts.second!,
  );
  return wallClock - Math.floor(instant / 1000) * 1000;
}

export function nextCostaRicaMidnight(now: Date): Date {
  const [year, month, day] = costaRicaDay(now).split('-').map(Number);
  const midnightAsUtc = Date.UTC(year!, month! - 1, day! + 1);
  return new Date(midnightAsUtc - offsetAt(midnightAsUtc));
}
