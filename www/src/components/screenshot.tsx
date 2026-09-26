import { DARK_SCHEME } from "#/hooks/use-prefers-dark";
import { cn } from "#/lib/cn";

/** Below Tailwind's `sm`, where a whole window is too small to read. */
const PHONE_SCREEN = "(max-width: 639.98px)";

export type ScreenshotCrop = { name: string; width: number; height: number };

const RETINA_SCALE = 2;

const displayWidth = (width: number) => ({ width: width / RETINA_SCALE });

type Scheme = "light" | "dark";

const screenshotUrl = (name: string, scheme?: Scheme) =>
  `/screenshots/${name}${scheme ? `-${scheme}` : ""}.avif`;

/**
 * An app screenshot, captured once in each appearance unless `themed` is off,
 * in which case one capture serves both. The browser picks the `<source>`
 * matching the colour scheme and downloads only that one variant. With a
 * `phone` crop, phones get a closer, taller capture of one corner of the
 * window instead of the whole window shrunk past legibility.
 */
export function Screenshot({
  alt,
  className,
  height,
  lazy = false,
  name,
  phone,
  themed = true,
  width,
}: {
  alt: string;
  className?: string;
  height: number;
  lazy?: boolean;
  name: string;
  phone?: ScreenshotCrop;
  themed?: boolean;
  width: number;
}) {
  const lightOrOnly = themed ? "light" : undefined;

  return (
    <picture>
      {phone && themed && (
        <source
          height={phone.height}
          media={`${PHONE_SCREEN} and ${DARK_SCHEME}`}
          srcSet={screenshotUrl(phone.name, "dark")}
          width={phone.width}
        />
      )}
      {phone && (
        <source
          height={phone.height}
          media={PHONE_SCREEN}
          srcSet={screenshotUrl(phone.name, lightOrOnly)}
          width={phone.width}
        />
      )}
      {themed && (
        <source
          height={height}
          media={DARK_SCHEME}
          srcSet={screenshotUrl(name, "dark")}
          width={width}
        />
      )}
      <img
        alt={alt}
        className={cn("block h-auto max-w-full", className)}
        decoding="async"
        height={height}
        loading={lazy ? "lazy" : "eager"}
        src={screenshotUrl(name, lightOrOnly)}
        style={displayWidth(width)}
        width={width}
      />
    </picture>
  );
}

const TRAFFIC_LIGHTS = ["bg-[#ff5f57]", "bg-[#febc2e]", "bg-[#28c840]"];

export function ScreenshotPlaceholder({
  alt,
  height,
  name,
  width,
}: {
  alt: string;
  height: number;
  name: string;
  width: number;
}) {
  return (
    <div
      aria-label={alt}
      className="relative flex max-w-full items-center justify-center bg-linear-135 from-sky-200 via-indigo-200 to-rose-200 p-[6%] dark:from-sky-950 dark:via-indigo-950 dark:to-rose-950"
      role="img"
      style={{ ...displayWidth(width), aspectRatio: `${width} / ${height}` }}
    >
      <div className="flex size-full flex-col overflow-hidden rounded-[min(1.2vw,10px)] bg-white/85 shadow-[0_20px_50px_rgba(0,0,0,0.12)] ring-1 ring-black/5 dark:bg-neutral-900/85 dark:ring-white/10">
        <div className="flex h-[7%] min-h-4 shrink-0 items-center gap-[0.6%] border-b border-black/5 px-[1.6%] dark:border-white/10">
          {TRAFFIC_LIGHTS.map((color) => (
            <span
              className={cn("aspect-square h-[40%] rounded-full", color)}
              key={color}
            />
          ))}
        </div>
        <div className="flex flex-1 flex-col items-center justify-center gap-1 p-4 text-center">
          <p className="text-sm font-medium text-neutral-500 sm:text-base dark:text-neutral-400">
            Screenshot coming soon
          </p>
          <p className="font-mono text-[11px] text-neutral-400 sm:text-xs dark:text-neutral-500">
            /screenshots/{name}-light.avif · {width}×{height}
          </p>
        </div>
      </div>
    </div>
  );
}
