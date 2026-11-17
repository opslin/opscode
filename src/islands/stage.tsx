// The new-chat background: a sonar dot field with pixel stars on top, coloured by the chosen
// mode (Normal, GODMODE, WARLORD, SHINOBI). Drawn behind the mascot and the composer.

import { BackgroundPixelStars } from "@/components/ui/background-pixel-stars";
import { SonarGrid } from "@/components/ui/sonar-grid";

export type StageSnap = {
  /** "normal" | "godmode" | "warlord" | "shinobi" */
  mode: string;
  /** Star palette. */
  stars: string[];
  /** Shooting-star trail, "r, g, b". */
  trail: string;
  /** Sonar dot colour. */
  dot: string;
  /** Seconds between sonar pings. */
  ping: number;
};

const AREA: [number, number, number, number] = [0.2, 0.18, 0.8, 0.62];

export function Stage({ s }: { s: StageSnap }) {
  return (
    <SonarGrid
      data-mode={s.mode}
      className="op-stage-grid size-full cursor-default"
      color={s.dot}
      spacing={24}
      dotRadius={1.15}
      baseOpacity={0.14}
      pingEvery={s.ping}
      speed={230}
      ringWidth={80}
      amplitude={1.9}
      maxRings={4}
      pingArea={AREA}
    >
      {/* Remount per mode: the pasted star component reads its props once. */}
      <BackgroundPixelStars key={s.mode} contained colors={s.stars} trailColor={s.trail} density={0.000045} />
    </SonarGrid>
  );
}
