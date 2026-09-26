type IconProps = { className?: string };

const SYMBOL = {
  fill: "none",
  stroke: "currentColor",
  strokeWidth: 1.7,
  strokeLinecap: "round",
  strokeLinejoin: "round",
} as const;

function Symbol({
  className,
  children,
}: IconProps & { children: React.ReactNode }) {
  return (
    <svg
      className={className}
      viewBox="0 0 24 24"
      aria-hidden="true"
      {...SYMBOL}
    >
      {children}
    </svg>
  );
}

export function Zoom({ className }: IconProps) {
  return (
    <Symbol className={className}>
      <circle cx="10.5" cy="10.5" r="6.5" />
      <path d="m15.3 15.3 5.2 5.2M10.5 7.8v5.4M7.8 10.5h5.4" />
    </Symbol>
  );
}

export function Display({ className }: IconProps) {
  return (
    <Symbol className={className}>
      <rect x="3" y="4" width="18" height="12.5" rx="2.2" />
      <path d="M9 20.2h6M12 16.5v3.7" />
    </Symbol>
  );
}

export function Window({ className }: IconProps) {
  return (
    <Symbol className={className}>
      <rect x="3" y="4.5" width="18" height="15" rx="3" />
      <path d="M3 9h18" />
      <circle cx="6.2" cy="6.8" r=".5" fill="currentColor" />
      <circle cx="8.4" cy="6.8" r=".5" fill="currentColor" />
    </Symbol>
  );
}

export function Camera({ className }: IconProps) {
  return (
    <Symbol className={className}>
      <rect x="2.8" y="6.5" width="12.7" height="11" rx="2.6" />
      <path d="m15.5 10.6 4.2-2.6c.5-.3 1.1.1 1.1.6v6.8c0 .6-.6.9-1.1.6l-4.2-2.6" />
    </Symbol>
  );
}

export function Microphone({ className }: IconProps) {
  return (
    <Symbol className={className}>
      <rect x="9" y="3.5" width="6" height="11" rx="3" />
      <path d="M5.8 11.5a6.2 6.2 0 0 0 12.4 0M12 17.7v2.8" />
    </Symbol>
  );
}

export function Folders({ className }: IconProps) {
  return (
    <Symbol className={className}>
      <path d="M7.5 7.8V6.6c0-1 .8-1.9 1.9-1.9h2.3l1.6 1.8h4.3c1 0 1.9.8 1.9 1.9v.4" />
      <path d="M4.5 10.3c0-1 .8-1.9 1.9-1.9h2.9L11 10.2h4.6c1 0 1.9.8 1.9 1.9v5.4c0 1-.8 1.9-1.9 1.9H6.4c-1 0-1.9-.8-1.9-1.9v-7.2Z" />
    </Symbol>
  );
}

export function Frame({ className }: IconProps) {
  return (
    <Symbol className={className}>
      <rect x="3" y="4.5" width="18" height="15" rx="3" />
      <rect x="7" y="8.5" width="10" height="7" rx="1.6" />
    </Symbol>
  );
}

export function Waveform({ className }: IconProps) {
  return (
    <Symbol className={className}>
      <path d="M4 10.5v3M8 7v10M12 4v16M16 8v8M20 10.5v3" />
    </Symbol>
  );
}

export function Document({ className }: IconProps) {
  return (
    <Symbol className={className}>
      <path d="M6 5.8c0-1 .8-1.9 1.9-1.9h5l5.1 5.1v9.2c0 1-.8 1.9-1.9 1.9H7.9c-1 0-1.9-.8-1.9-1.9V5.8Z" />
      <path d="M12.8 4v3.3c0 .9.7 1.6 1.6 1.6H18" />
    </Symbol>
  );
}

export function Laptop({ className }: IconProps) {
  return (
    <Symbol className={className}>
      <rect x="4.5" y="5" width="15" height="10.5" rx="1.8" />
      <path d="M2.5 18.6h19" />
    </Symbol>
  );
}

export function Apple({ className }: IconProps) {
  return (
    <svg className={className} viewBox="0 0 24 24" aria-hidden="true">
      <path
        fill="currentColor"
        d="M16.37 12.62c-.02-2.3 1.88-3.4 1.96-3.46-1.07-1.56-2.73-1.78-3.32-1.8-1.41-.14-2.76.83-3.47.83-.72 0-1.82-.81-2.99-.79-1.54.02-2.96.9-3.75 2.27-1.6 2.78-.41 6.89 1.15 9.14.76 1.1 1.67 2.34 2.86 2.3 1.15-.05 1.58-.74 2.96-.74 1.38 0 1.77.74 2.98.72 1.23-.02 2.01-1.12 2.76-2.23.87-1.28 1.23-2.52 1.25-2.58-.03-.01-2.4-.92-2.42-3.66ZM14.1 5.87c.63-.77 1.06-1.83.94-2.89-.91.04-2.01.61-2.66 1.37-.58.67-1.09 1.76-.96 2.79 1.02.08 2.05-.51 2.68-1.27Z"
      />
    </svg>
  );
}
