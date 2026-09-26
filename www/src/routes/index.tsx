import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";

import { NoteCard, ShowcaseCard } from "#/components/card";
import { Container } from "#/components/container";
import {
  Apple,
  Camera,
  Display,
  Document,
  Folders,
  Frame,
  Laptop,
  Microphone,
  Waveform,
  Window,
  Zoom,
} from "#/components/icons";
import {
  Screenshot,
  ScreenshotPlaceholder,
  type ScreenshotCrop,
} from "#/components/screenshot";
import { cn } from "#/lib/cn";
import { SiteFooter } from "#/components/site-footer";
import { SiteHeader } from "#/components/site-header";
import { DOWNLOAD_URL, REPO_URL } from "#/lib/links";

type ScreenshotSpec = {
  width: number;
  height: number;
  capture: "pending" | "single" | "themed";
};

const SCREENSHOTS = {
  editor: { width: 2880, height: 1778, capture: "single" },
  "auto-zoom": { width: 2506, height: 1084, capture: "single" },
  "capture-display": { width: 2578, height: 1106, capture: "single" },
  "capture-window": { width: 2578, height: 1106, capture: "single" },
  "devices-camera": { width: 2576, height: 1082, capture: "single" },
  "devices-microphone": { width: 2576, height: 1082, capture: "single" },
  "camera-bubble": { width: 2560, height: 1588, capture: "single" },
  library: { width: 1274, height: 1402, capture: "single" },
} as const satisfies Record<string, ScreenshotSpec>;

type ScreenshotName = keyof typeof SCREENSHOTS;

const specFor = (name: ScreenshotName): ScreenshotSpec => SCREENSHOTS[name];

const SECTION_ICON = "size-7 lg:size-10";
const NOTE_ICON = "size-7 lg:size-8";

const HERO_PHONE_CROP: ScreenshotCrop = {
  name: "editor-mobile",
  width: 1060,
  height: 1232,
};

export const Route = createFileRoute("/")({
  component: Home,
});

function AppScreenshot({
  label,
  lazy = false,
  name,
  phone,
}: {
  label: string;
  lazy?: boolean;
  name: ScreenshotName;
  phone?: ScreenshotCrop;
}) {
  const { width, height, capture } = specFor(name);

  if (capture === "pending") {
    return (
      <ScreenshotPlaceholder
        alt={label}
        height={height}
        name={name}
        width={width}
      />
    );
  }

  return (
    <Screenshot
      alt={label}
      height={height}
      lazy={lazy}
      name={name}
      phone={phone}
      themed={capture === "themed"}
      width={width}
    />
  );
}

function SectionScreenshot(props: { label: string; name: ScreenshotName }) {
  return <AppScreenshot lazy {...props} />;
}

type ScreenshotOption = {
  name: ScreenshotName;
  label: string;
  icon: typeof Display;
  alt: string;
};

const CAPTURE_TARGETS = [
  {
    name: "capture-window",
    label: "Window",
    icon: Window,
    alt: "The recording toolbar set to record a single Safari window",
  },
  {
    name: "capture-display",
    label: "Display",
    icon: Display,
    alt: "The recording toolbar over the desktop, set to record the whole display",
  },
] as const satisfies ReadonlyArray<ScreenshotOption>;

const INPUT_DEVICES = [
  {
    name: "devices-camera",
    label: "Camera",
    icon: Camera,
    alt: "The camera menu in the recording toolbar, listing the Studio Display, MacBook Pro and iPhone cameras",
  },
  {
    name: "devices-microphone",
    label: "Microphone",
    icon: Microphone,
    alt: "The microphone menu in the recording toolbar, listing built-in, iPhone, Studio Display and USB microphones",
  },
] as const satisfies ReadonlyArray<ScreenshotOption>;

function ScreenshotSwitcher({
  label,
  options,
  value,
  onChange,
}: {
  label: string;
  options: ReadonlyArray<ScreenshotOption>;
  value: ScreenshotName;
  onChange: (name: ScreenshotName) => void;
}) {
  const selectedIndex = options.findIndex((option) => option.name === value);

  return (
    <div
      aria-label={label}
      className="relative grid w-full grid-cols-2 rounded-full bg-black/[0.05] p-1 ring-1 ring-black/[0.04] ring-inset sm:inline-grid sm:w-auto dark:bg-white/[0.06] dark:ring-white/[0.06]"
      role="group"
    >
      <span
        aria-hidden="true"
        className="absolute inset-y-1 left-1 w-[calc(50%-4px)] rounded-full bg-white shadow-[0_1px_3px_rgba(0,0,0,0.1),0_0_0_0.5px_rgba(0,0,0,0.06)] transition-transform duration-300 ease-[cubic-bezier(0.25,1,0.5,1)] motion-reduce:transition-none dark:bg-white/[0.14] dark:shadow-[0_1px_3px_rgba(0,0,0,0.3),inset_0_0.5px_0_rgba(255,255,255,0.08)]"
        style={{ transform: `translateX(${selectedIndex * 100}%)` }}
      />
      {options.map(({ name, label: optionLabel, icon: Icon }) => {
        const selected = name === value;
        return (
          <button
            aria-pressed={selected}
            className={cn(
              "relative inline-flex h-10 items-center justify-center gap-1.5 rounded-full px-3 text-sm font-medium whitespace-nowrap transition-colors duration-200 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-neutral-400 sm:h-8 sm:px-4 sm:text-[13px] lg:h-10 lg:px-5 lg:text-[15px]",
              selected
                ? "text-neutral-900 dark:text-white"
                : "text-neutral-500 hover:text-neutral-800 dark:text-neutral-400 dark:hover:text-neutral-200"
            )}
            key={name}
            onClick={() => onChange(name)}
            type="button"
          >
            <Icon className="size-4 lg:size-4.5" />
            {optionLabel}
          </button>
        );
      })}
    </div>
  );
}

/**
 * Every option stays mounted in one grid cell and crossfades, so switching
 * never waits on a download or shifts the page.
 */
function SwitchableShowcaseCard({
  description,
  icon,
  options,
  switcherLabel,
  title,
}: {
  description: string;
  icon: React.ReactNode;
  options: ReadonlyArray<ScreenshotOption>;
  switcherLabel: string;
  title: string;
}) {
  const [shownName, setShownName] = useState(options[0].name);

  return (
    <ShowcaseCard
      controls={
        <ScreenshotSwitcher
          label={switcherLabel}
          onChange={setShownName}
          options={options}
          value={shownName}
        />
      }
      description={description}
      icon={icon}
      title={title}
    >
      <div className="grid">
        {options.map(({ name, alt }) => {
          const shown = name === shownName;
          return (
            <div
              aria-hidden={!shown}
              className={cn(
                "transition-opacity duration-300 ease-out [grid-area:1/1] motion-reduce:transition-none",
                !shown && "opacity-0"
              )}
              key={name}
            >
              <SectionScreenshot label={alt} name={name} />
            </div>
          );
        })}
      </div>
    </ShowcaseCard>
  );
}

function Hero() {
  return (
    <section className="flex flex-col items-center gap-6 pt-24 pb-10 text-center sm:pt-36 sm:pb-16 lg:pt-44 lg:pb-20">
      <h1 className="max-w-2xl text-[30px] leading-[1.1] font-bold tracking-[-0.02em] text-balance sm:text-[44px] lg:max-w-4xl lg:text-[62px]">
        Your screen, your face, your voice, in one take
      </h1>

      <p className="max-w-2xl text-lg leading-normal text-pretty text-neutral-600 sm:text-[21px] lg:max-w-3xl lg:text-2xl lg:leading-[1.4] dark:text-neutral-400">
        ScreenChest zooms in on your clicks, so viewers always see what you're
        doing. A lightweight native Mac app with a built-in editor.
      </p>

      <a
        className="mt-4 inline-flex h-12 items-center justify-center gap-2.5 rounded-full bg-neutral-900 px-7 text-[17px] font-semibold text-white transition-colors hover:bg-neutral-700 lg:h-14 lg:px-8 lg:text-lg dark:bg-white dark:text-neutral-900 dark:hover:bg-neutral-200"
        href={DOWNLOAD_URL}
      >
        <Apple className="size-5 lg:size-6" />
        Download for macOS
      </a>

      <p className="text-sm leading-relaxed text-pretty text-neutral-500 sm:text-[13px] lg:text-[15px]">
        For Apple silicon Macs, on macOS 26 or later. Free and{" "}
        <a
          className="underline decoration-neutral-300 underline-offset-2 transition-colors hover:text-neutral-900 dark:decoration-neutral-600 dark:hover:text-white"
          href={REPO_URL}
          rel="noopener noreferrer"
          target="_blank"
        >
          open source
        </a>
        .
      </p>
    </section>
  );
}

function Home() {
  return (
    <>
      <SiteHeader />

      <main className="flex flex-col gap-6">
        <Container>
          <Hero />
        </Container>

        <Container className="max-w-[1440px] lg:max-w-[1440px]">
          <div className="screen-shadow overflow-hidden rounded-[min(2vw,12px)] ring-1 ring-black/10 dark:ring-white/10">
            <AppScreenshot
              label="The ScreenChest editor previewing a desktop recording, with zoom, background, audio and export settings beside it and zooms on the timeline below"
              name="editor"
              phone={HERO_PHONE_CROP}
            />
          </div>
        </Container>

        <Container className="mt-6 flex flex-col gap-4 sm:mt-10 sm:gap-16">
          <ShowcaseCard
            description="ScreenChest adds zooms by following your clicks and cursor, so the important moments stand out. It gets you most of the way, and you finish the rest: drag, resize, or add zooms right on the timeline."
            icon={<Zoom className={SECTION_ICON} />}
            title="Automatic zooms"
          >
            <SectionScreenshot
              label="The timeline's zoom row, with 2× zooms placed under each burst of clicks"
              name="auto-zoom"
            />
          </ShowcaseCard>

          <SwitchableShowcaseCard
            description="Camera, microphone and system audio record alongside it, lined up to the same frame."
            icon={<Display className={SECTION_ICON} />}
            options={CAPTURE_TARGETS}
            switcherLabel="Capture target"
            title="Record a display, or just one window"
          />

          <SwitchableShowcaseCard
            description="Pick from every camera and microphone your Mac can see: the built-in ones, a Studio Display, a USB mic, or your iPhone through Continuity Camera."
            icon={<Microphone className={SECTION_ICON} />}
            options={INPUT_DEVICES}
            switcherLabel="Input device"
            title="Use any connected camera or microphone"
          />

          <ShowcaseCard
            description="Add your camera as a bubble and pick its corner, size and shape. Mirror it so you look the way you expect to."
            icon={<Camera className={SECTION_ICON} />}
            title="Put yourself in the corner"
          >
            <SectionScreenshot
              label="A rounded camera bubble in the bottom-left corner of the recording, beside its position, shape, size and mirror settings"
              name="camera-bubble"
            />
          </ShowcaseCard>

          <ShowcaseCard
            description="Every take lands in one library, with thumbnails, search and the edits you made to each. Pick one up right where you left it."
            icon={<Folders className={SECTION_ICON} />}
            title="All your recordings in one place"
          >
            <SectionScreenshot
              label="The recording picker, with a search field and thumbnails of today's and yesterday's takes"
              name="library"
            />
          </ShowcaseCard>
        </Container>

        <Container className="grid grid-cols-1 gap-4 sm:mt-10 sm:grid-cols-2 sm:gap-8">
          <NoteCard
            icon={<Frame className={NOTE_ICON} />}
            title="Frame it nicely"
          >
            Set your recording on a wallpaper or gradient, with padding, rounded
            corners and a shadow.
          </NoteCard>
          <NoteCard icon={<Waveform className={NOTE_ICON} />} title="Audio">
            Balance your microphone against system audio before you export.
          </NoteCard>
          <NoteCard
            icon={<Document className={NOTE_ICON} />}
            title="Plain files on your Mac"
          >
            Each recording is a package in your Movies folder, edits included.
          </NoteCard>
          <NoteCard
            icon={<Laptop className={NOTE_ICON} />}
            title="Native to the Mac"
          >
            Built with SwiftUI for macOS 26 and later.
          </NoteCard>
        </Container>

        <div className="mt-4 sm:mt-10">
          <SiteFooter />
        </div>
      </main>
    </>
  );
}
