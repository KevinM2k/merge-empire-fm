import { useEffect, useRef, useState } from 'react';
import './CoinCounter.css';

export interface CoinCounterProps {
  value: number;
  /** A counter that goes up once per reward. Its VALUE means nothing; that it
   *  changed is the whole signal — idle income moves `value` every second, and
   *  a figure that pulses every second is furniture. */
  reward?: number;
  className?: string;
}

/** Compact coins: 1.2K, 3.4M. */
export function formatCoinsCompact(v: number): string {
  const n = Math.floor(v);
  if (n < 1000) return String(n);
  for (const [unit, at] of [['B', 1e9], ['M', 1e6], ['K', 1e3]] as const) {
    if (n >= at) {
      const scaled = n / at;
      return `${scaled < 10 ? scaled.toFixed(1).replace(/\.0$/, '') : Math.floor(scaled)}${unit}`;
    }
  }
  return String(n);
}

/** The coin figure, counting up rather than snapping — and swelling when what
 *  moved it was something the player DID. Out and BACK on one pass, or the
 *  counter stays permanently larger after the first reward of the session. */
export function CoinCounter({ value, reward = 0, className }: CoinCounterProps) {
  const [shown, setShown] = useState(value);
  const [swell, setSwell] = useState(false);
  const from = useRef(value);
  const firstReward = useRef(reward);

  useEffect(() => {
    const start = performance.now();
    const a = from.current;
    const b = value;
    if (a === b) return;
    let raf = 0;
    const tick = (now: number) => {
      const t = Math.min(1, (now - start) / 600);
      const eased = 1 - Math.pow(1 - t, 3); // easeOut
      setShown(a + (b - a) * eased);
      if (t < 1) raf = requestAnimationFrame(tick);
      else from.current = b;
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [value]);

  useEffect(() => {
    if (reward === firstReward.current) return;
    firstReward.current = reward;
    setSwell(true);
    const id = setTimeout(() => setSwell(false), 420);
    return () => clearTimeout(id);
  }, [reward]);

  return (
    <span className={['me-coins', swell && 'me-coins--swell', className].filter(Boolean).join(' ')}>
      {formatCoinsCompact(shown)}
    </span>
  );
}
