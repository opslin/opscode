"use client";

// Pasted component (21st.dev "background-pixel-stars"). Opscode: changes are marked "Opscode:".
//  - colors / trailColor props so each mode gets its own palette (remount with a `key` to switch);
//  - contained: sizes to the parent element instead of the window (it lives inside the chat pane);
//  - the shooting-star timer and resize work are cleaned up on unmount;
//  - pauses while the tab is hidden and draws one still frame under prefers-reduced-motion.

import { memo, useCallback, useEffect, useRef } from "react";

// 16-bit color palette (reduced color options)
const STAR_COLORS = [
  "#FFFFFF", // White
  "#FFFFAA", // Light yellow
  "#AAAAFF", // Light blue
  "#FFAAAA", // Light red
  "#AAFFAA", // Light green
  "#FFAAFF", // Light purple
  "#AAFFFF", // Light cyan
] as const;

// Configuration constants
const starDensity = 0.00004; // Reduced density for larger stars
const twinkleProbability = 0.7;
const minTwinkleSpeed = 2;
const maxTwinkleSpeed = 4;
const pixelSize = 5;
const starRegenerationInterval = 5000; // Interval to regenerate stars (in ms)
const percentToRegenerate = 0.15; // Percentage of stars to regenerate at each interval

// Shooting star configuration
const shootingStarPixelSize = 2;
const targetFps = 16; // 16 FPS for that retro feel

type BackgroundStar = {
  x: number;
  y: number;
  color: string;
  baseOpacity: number;
  currentOpacity: number;
  twinkle: boolean;
  twinkleSpeed: number;
  twinkleDirection: number; // -1 fading out, 1 fading in
  twinkleTimer: number;
};

type TrailPoint = { x: number; y: number; opacity: number };

type ShootingStar = {
  id: number;
  x: number;
  y: number;
  angle: number;
  scale: number;
  speed: number;
  distance: number;
  trail: TrailPoint[];
};

type StartPoint = { x: number; y: number; angle: number };

export type BackgroundPixelStarsProps = {
  /** Opscode: star palette (any CSS colors). */
  colors?: readonly string[];
  /** Opscode: shooting-star trail as "r, g, b". */
  trailColor?: string;
  /** Opscode: fill the parent element (absolute) instead of the window (fixed). */
  contained?: boolean;
  /** Opscode: stars per square pixel. */
  density?: number;
  className?: string;
};

export const BackgroundPixelStars = memo(
  ({ colors = STAR_COLORS, trailColor = "180, 242, 255", contained = false, density = starDensity, className }: BackgroundPixelStarsProps) => {
    const canvasRef = useRef<HTMLCanvasElement | null>(null);
    const animationFrameRef = useRef<number | null>(null);

    const backgroundStarsRef = useRef<BackgroundStar[]>([]);
    const shootingStarsRef = useRef<ShootingStar[]>([]);
    const lastRenderTimeRef = useRef<number>(0);
    const frameInterval: number = 1000 / targetFps;

    // Opscode: the drawing area (window, or the parent element when contained).
    const area = useCallback((): { w: number; h: number } => {
      const parent = canvasRef.current?.parentElement;
      if (contained && parent) return { w: parent.clientWidth, h: parent.clientHeight };
      return { w: window.innerWidth, h: window.innerHeight };
    }, [contained]);

    const makeStar = useCallback((canvas: HTMLCanvasElement): BackgroundStar => {
      const shouldTwinkle = Math.random() < twinkleProbability;
      const gridX = Math.floor(Math.random() * (canvas.width / pixelSize)) * pixelSize;
      const gridY = Math.floor(Math.random() * (canvas.height / pixelSize)) * pixelSize;
      const colorIndex = Math.floor(Math.random() * colors.length);
      const baseOpacity = Math.random() * 0.5 + 0.5;
      return {
        x: gridX,
        y: gridY,
        color: colors[colorIndex]!,
        baseOpacity,
        currentOpacity: baseOpacity,
        twinkle: shouldTwinkle,
        twinkleSpeed: minTwinkleSpeed + Math.random() * (maxTwinkleSpeed - minTwinkleSpeed),
        twinkleDirection: -1,
        twinkleTimer: 0,
      };
    }, [colors]);

    // Get random starting point for shooting stars: anywhere along the top edge, 45-135 degrees.
    const getRandomStartPoint = useCallback((): StartPoint => {
      const x = Math.random() * area().w;
      const angle = 45 + Math.random() * 90;
      return { x, y: 0, angle };
    }, [area]);

    const createNewShootingStar = useCallback((): ShootingStar => {
      const { x, y, angle } = getRandomStartPoint();
      return { id: Date.now(), x, y, angle, scale: 1, speed: Math.random() * 5 + 8, distance: 0, trail: [] };
    }, [getRandomStartPoint]);

    const initBackgroundStars = useCallback((): void => {
      const canvas = canvasRef.current;
      if (!canvas) return;
      backgroundStarsRef.current = [];
      const numStars = Math.floor(canvas.width * canvas.height * density);
      for (let i = 0; i < numStars; i++) backgroundStarsRef.current.push(makeStar(canvas));
    }, [density, makeStar]);

    const regenerateBackgroundStars = useCallback((): void => {
      const canvas = canvasRef.current;
      if (!canvas || backgroundStarsRef.current.length === 0) return;
      const numToRegenerate = Math.max(1, Math.floor(backgroundStarsRef.current.length * percentToRegenerate));
      for (let i = 0; i < numToRegenerate; i++) {
        const randomIndex = Math.floor(Math.random() * backgroundStarsRef.current.length);
        backgroundStarsRef.current[randomIndex] = makeStar(canvas);
      }
    }, [makeStar]);

    const drawFrame = useCallback((ctx: CanvasRenderingContext2D, canvas: HTMLCanvasElement): void => {
      ctx.clearRect(0, 0, canvas.width, canvas.height);

      // 1. Background stars (twinkle in discrete steps)
      backgroundStarsRef.current.forEach((star) => {
        ctx.fillStyle = star.color;
        ctx.globalAlpha = star.currentOpacity;
        ctx.fillRect(star.x, star.y, pixelSize, pixelSize);
        if (star.twinkle) {
          star.twinkleTimer += 1 / targetFps;
          if (star.twinkleTimer >= star.twinkleSpeed) {
            star.twinkleTimer = 0;
            star.twinkleDirection *= -1;
          }
          const progress = star.twinkleTimer / star.twinkleSpeed;
          if (progress < 0.5) star.currentOpacity = star.twinkleDirection < 0 ? star.baseOpacity : star.baseOpacity * 0.3;
          else star.currentOpacity = star.twinkleDirection < 0 ? star.baseOpacity * 0.3 : star.baseOpacity;
        }
      });
      ctx.globalAlpha = 1;

      // 2. Shooting stars
      if (!shootingStarsRef.current.length) return;
      shootingStarsRef.current = shootingStarsRef.current
        .map((star) => {
          const newX = star.x + star.speed * Math.cos((star.angle * Math.PI) / 180);
          const newY = star.y + star.speed * Math.sin((star.angle * Math.PI) / 180);
          const newDistance = star.distance + star.speed;
          const newTrail = [...star.trail];
          if (newDistance % 8 < star.speed) newTrail.push({ x: star.x, y: star.y, opacity: 1.0 });
          const updatedTrail = newTrail.map((p) => ({ ...p, opacity: p.opacity - 0.1 })).filter((p) => p.opacity > 0);
          return { ...star, x: newX, y: newY, distance: newDistance, trail: updatedTrail };
        })
        .filter((star) => star.x >= -30 && star.x <= canvas.width + 30 && star.y >= -30 && star.y <= canvas.height + 30);

      // 3. Draw shooting stars
      shootingStarsRef.current.forEach((star) => {
        star.trail.forEach((point) => {
          ctx.save();
          ctx.translate(point.x, point.y);
          ctx.rotate((star.angle * Math.PI) / 180);
          ctx.translate(-point.x, -point.y);
          ctx.fillStyle = `rgba(${trailColor}, ${point.opacity})`;
          ctx.fillRect(point.x, point.y, shootingStarPixelSize, shootingStarPixelSize);
          ctx.restore();
        });
        const starWidth = 4;
        const starHeight = 2;
        ctx.save();
        ctx.translate(star.x, star.y);
        ctx.rotate((star.angle * Math.PI) / 180);
        ctx.translate(-star.x, -star.y);
        ctx.fillStyle = "#ffffff";
        ctx.globalAlpha = 1.0;
        for (let y = 0; y < starHeight; y++) {
          for (let x = 0; x < starWidth; x++) {
            if ((x === 0 && y === 1) || (x === 3 && y === 0)) continue;
            ctx.fillRect(star.x + x * shootingStarPixelSize, star.y + y * shootingStarPixelSize, shootingStarPixelSize, shootingStarPixelSize);
          }
        }
        ctx.restore();
      });
    }, [trailColor]);

    const animateCanvas = useCallback((timestamp: number): void => {
      animationFrameRef.current = requestAnimationFrame(animateCanvas);
      if (timestamp - lastRenderTimeRef.current < frameInterval || document.hidden) return;
      lastRenderTimeRef.current = timestamp;
      const canvas = canvasRef.current;
      const ctx = canvas?.getContext("2d");
      if (canvas && ctx) drawFrame(ctx, canvas);
    }, [frameInterval, drawFrame]);

    useEffect(() => {
      const canvas = canvasRef.current;
      if (!canvas) return;
      const size = (): void => {
        const { w, h } = area();
        if (canvas.width === w && canvas.height === h) return;
        canvas.width = w;
        canvas.height = h;
        initBackgroundStars();
      };
      size();
      initBackgroundStars();

      const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
      if (reduce) {
        const ctx = canvas.getContext("2d");
        if (ctx) drawFrame(ctx, canvas);
      } else {
        animationFrameRef.current = requestAnimationFrame(animateCanvas);
      }

      // Shooting stars every 2-6 seconds.
      let shootTimer = 0;
      const createShootingStar = (): void => {
        if (!document.hidden) shootingStarsRef.current = [...shootingStarsRef.current, createNewShootingStar()];
        shootTimer = window.setTimeout(createShootingStar, Math.random() * 4000 + 2000);
      };
      if (!reduce) shootTimer = window.setTimeout(createShootingStar, 600);

      const regenerationInterval = window.setInterval(regenerateBackgroundStars, starRegenerationInterval);

      // Opscode: follow the parent's size when contained, the window otherwise.
      const ro = contained && canvas.parentElement ? new ResizeObserver(size) : null;
      if (ro && canvas.parentElement) ro.observe(canvas.parentElement);
      if (!ro) window.addEventListener("resize", size);

      return () => {
        if (animationFrameRef.current) cancelAnimationFrame(animationFrameRef.current);
        window.clearTimeout(shootTimer);
        window.clearInterval(regenerationInterval);
        ro?.disconnect();
        window.removeEventListener("resize", size);
      };
    }, [animateCanvas, area, contained, createNewShootingStar, drawFrame, initBackgroundStars, regenerateBackgroundStars]);

    return (
      <canvas
        ref={canvasRef}
        aria-hidden="true"
        className={className ?? (contained ? "pointer-events-none absolute inset-0" : "pointer-events-none fixed inset-0")}
      />
    );
  },
  () => true,
);

export default BackgroundPixelStars;
