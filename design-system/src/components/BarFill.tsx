
import './BarFill.css';

export interface BarFillProps {
  /** 0..1 of the track's width. Clamped here rather than at every call site: a
   *  fraction derived from a clock can run a hair past 1 on the first frame. */
  fraction: number;
  /** The fill's colour. */
  fill?: string;
  track?: string;
  height?: number;
  /** Which end it grows from. A countdown sweeping away wants 'right'. */
  from?: 'left' | 'right';
  className?: string;
}

/** A fill across a track: a fraction of its width, and ALL of its height.
 *  The full-height half is the entire reason this exists — it has been the
 *  same bug four separate times. */
export function BarFill({
  fraction, fill, track, height = 6, from = 'left', className,
}: BarFillProps) {
  const pct = Math.max(0, Math.min(1, fraction)) * 100;
  return (
    <div
      className={['me-bar', className].filter(Boolean).join(' ')}
      style={{ height, background: track ?? 'var(--color-surface-2)' }}
      role="progressbar"
      aria-valuenow={Math.round(pct)}
      aria-valuemin={0}
      aria-valuemax={100}
    >
      <div
        className="me-bar__fill"
        style={{
          width: `${pct}%`,
          background: fill ?? 'var(--color-accent)',
          marginLeft: from === 'right' ? 'auto' : undefined,
        }}
      />
    </div>
  );
}
