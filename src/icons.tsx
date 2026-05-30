import React from "react";
import Svg, { Circle, Path, Rect, Line, Polygon, G } from "react-native-svg";

type P = { size?: number; color?: string; sw?: number };

const I = ({
  size = 24, vb = "0 0 24 24", children,
}: { size: number; vb?: string; children: React.ReactNode }) => (
  <Svg width={size} height={size} viewBox={vb} fill="none">{children}</Svg>
);

export function IcoCommittee({ size = 24, color = "#fff", sw = 1.8 }: P) {
  return (
    <I size={size}>
      <Path d="M3 21V9L12 4L21 9V21" stroke={color} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round" />
      <Path d="M9 21V14H15V21" stroke={color} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round" />
      <Path d="M12 4V8" stroke={color} strokeWidth={sw} strokeLinecap="round" />
      <Path d="M7 12H9M15 12H17" stroke={color} strokeWidth={sw} strokeLinecap="round" />
    </I>
  );
}

export function IcoMembers({ size = 24, color = "#fff", sw = 1.8 }: P) {
  return (
    <I size={size}>
      <Circle cx="9" cy="7" r="4" stroke={color} strokeWidth={sw} />
      <Path d="M1 21v-2a6 6 0 0 1 6-6h4a6 6 0 0 1 6 6v2" stroke={color} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round" />
      <Path d="M16 3.13a4 4 0 0 1 0 7.75" stroke={color} strokeWidth={sw} strokeLinecap="round" />
      <Path d="M23 21v-2a4 4 0 0 0-3-3.87" stroke={color} strokeWidth={sw} strokeLinecap="round" />
    </I>
  );
}

export function IcoChat({ size = 24, color = "#fff", sw = 1.8 }: P) {
  return (
    <I size={size}>
      <Path d="M21 15c0 1.1-.9 2-2 2H7l-4 4V5c0-1.1.9-2 2-2h14c1.1 0 2 .9 2 2v10z" stroke={color} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round" />
    </I>
  );
}

export function IcoKuri({ size = 24, color = "#fff", sw = 1.8 }: P) {
  return (
    <I size={size}>
      <Circle cx="12" cy="12" r="9" stroke={color} strokeWidth={sw} />
      <Path d="M9 9h5a2.5 2.5 0 0 1 0 5H9M9 9v7M9 14h4" stroke={color} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round" />
    </I>
  );
}

export function IcoBell({ size = 24, color = "#fff", sw = 1.8 }: P) {
  return (
    <I size={size}>
      <Path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9" stroke={color} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round" />
      <Path d="M13.73 21a2 2 0 0 1-3.46 0" stroke={color} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round" />
    </I>
  );
}

export function IcoEdit({ size = 24, color = "#fff", sw = 1.8 }: P) {
  return (
    <I size={size}>
      <Path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7" stroke={color} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round" />
      <Path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z" stroke={color} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round" />
    </I>
  );
}

export function IcoTrash({ size = 24, color = "#fff", sw = 1.8 }: P) {
  return (
    <I size={size}>
      <Path d="M3 6h18M8 6V4a1 1 0 0 1 1-1h6a1 1 0 0 1 1 1v2M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6" stroke={color} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round" />
      <Path d="M10 11v6M14 11v6" stroke={color} strokeWidth={sw} strokeLinecap="round" />
    </I>
  );
}

export function IcoPlus({ size = 24, color = "#fff", sw = 1.8 }: P) {
  return (
    <I size={size}>
      <Path d="M12 5v14M5 12h14" stroke={color} strokeWidth={sw} strokeLinecap="round" />
    </I>
  );
}

export function IcoCheck({ size = 24, color = "#fff", sw = 1.8 }: P) {
  return (
    <I size={size}>
      <Path d="M22 11.08V12a10 10 0 1 1-5.93-9.14" stroke={color} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round" />
      <Path d="M22 4L12 14.01l-3-3" stroke={color} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round" />
    </I>
  );
}

export function IcoUpload({ size = 24, color = "#fff", sw = 1.8 }: P) {
  return (
    <I size={size}>
      <Path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" stroke={color} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round" />
      <Path d="M17 8l-5-5-5 5M12 3v12" stroke={color} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round" />
    </I>
  );
}

export function IcoCopy({ size = 24, color = "#fff", sw = 1.8 }: P) {
  return (
    <I size={size}>
      <Rect x="9" y="9" width="13" height="13" rx="2" stroke={color} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round" />
      <Path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1" stroke={color} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round" />
    </I>
  );
}

export function IcoQr({ size = 24, color = "#fff", sw = 1.5 }: P) {
  return (
    <I size={size}>
      <Rect x="3" y="3" width="7" height="7" rx="1" stroke={color} strokeWidth={sw} />
      <Rect x="14" y="3" width="7" height="7" rx="1" stroke={color} strokeWidth={sw} />
      <Rect x="3" y="14" width="7" height="7" rx="1" stroke={color} strokeWidth={sw} />
      <Rect x="5" y="5" width="3" height="3" fill={color} />
      <Rect x="16" y="5" width="3" height="3" fill={color} />
      <Rect x="5" y="16" width="3" height="3" fill={color} />
      <Path d="M14 14h2M18 14h2M14 18h2M18 18h2M16 16h2M20 16v2M20 20h-2M14 20v-2" stroke={color} strokeWidth={sw} strokeLinecap="round" />
    </I>
  );
}

export function IcoReceipt({ size = 24, color = "#fff", sw = 1.8 }: P) {
  return (
    <I size={size}>
      <Path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8l-6-6z" stroke={color} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round" />
      <Path d="M14 2v6h6" stroke={color} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round" />
      <Path d="M16 13H8M16 17H8M10 9H8" stroke={color} strokeWidth={sw} strokeLinecap="round" />
    </I>
  );
}

export function IcoSend({ size = 24, color = "#fff", sw = 1.8 }: P) {
  return (
    <I size={size}>
      <Polygon points="22 2 15 22 11 13 2 9 22 2" stroke={color} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round" fill="none" />
      <Path d="M22 2L11 13" stroke={color} strokeWidth={sw} strokeLinecap="round" />
    </I>
  );
}

export function IcoX({ size = 24, color = "#fff", sw = 1.8 }: P) {
  return (
    <I size={size}>
      <Path d="M18 6L6 18M6 6l12 12" stroke={color} strokeWidth={sw} strokeLinecap="round" />
    </I>
  );
}

export function IcoArrow({ size = 24, color = "#fff", sw = 1.8 }: P) {
  return (
    <I size={size}>
      <Path d="M9 18l6-6-6-6" stroke={color} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round" />
    </I>
  );
}

export function IcoMore({ size = 24, color = "#fff", sw = 2 }: P) {
  return (
    <I size={size}>
      <Circle cx="12" cy="12" r="1" fill={color} />
      <Circle cx="19" cy="12" r="1" fill={color} />
      <Circle cx="5" cy="12" r="1" fill={color} />
    </I>
  );
}

export function IcoSignOut({ size = 24, color = "#fff", sw = 1.8 }: P) {
  return (
    <I size={size}>
      <Path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" stroke={color} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round" />
      <Path d="M16 17l5-5-5-5M21 12H9" stroke={color} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round" />
    </I>
  );
}

export function IcoShield({ size = 24, color = "#fff", sw = 1.8 }: P) {
  return (
    <I size={size}>
      <Path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" stroke={color} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round" />
      <Path d="M9 12l2 2 4-4" stroke={color} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round" />
    </I>
  );
}

export function IcoInvite({ size = 24, color = "#fff", sw = 1.8 }: P) {
  return (
    <I size={size}>
      <Circle cx="12" cy="12" r="10" stroke={color} strokeWidth={sw} />
      <Path d="M12 8v8M8 12h8" stroke={color} strokeWidth={sw} strokeLinecap="round" />
    </I>
  );
}

export function IcoCalendar({ size = 24, color = "#fff", sw = 1.8 }: P) {
  return (
    <I size={size}>
      <Rect x="3" y="4" width="18" height="18" rx="2" stroke={color} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round" />
      <Path d="M16 2v4M8 2v4M3 10h18" stroke={color} strokeWidth={sw} strokeLinecap="round" />
    </I>
  );
}

export function IcoImage({ size = 24, color = "#fff", sw = 1.8 }: P) {
  return (
    <I size={size}>
      <Rect x="3" y="3" width="18" height="18" rx="2" stroke={color} strokeWidth={sw} />
      <Circle cx="8.5" cy="8.5" r="1.5" stroke={color} strokeWidth={sw} />
      <Path d="M21 15l-5-5L5 21" stroke={color} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round" />
    </I>
  );
}

// ─── App Logo ─────────────────────────────────────────────────────────────────
// Six-member hexagon arrangement with central rupee coin

export function AppLogo({ size = 48, color = "#22d3ee" }: { size?: number; color?: string }) {
  const cx = size / 2;
  const cy = size / 2;
  const R = size * 0.38;   // member dot orbit radius
  const r = size * 0.075;  // member dot radius
  const innerR = size * 0.2;

  const dots = Array.from({ length: 6 }, (_, i) => {
    const angle = (i * 60 - 90) * (Math.PI / 180);
    return { x: cx + R * Math.cos(angle), y: cy + R * Math.sin(angle) };
  });

  const hexPts = dots.map((d) => `${d.x},${d.y}`).join(" ");

  return (
    <Svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} fill="none">
      {/* Hexagon connector */}
      <Polygon points={hexPts} stroke={color} strokeWidth={size * 0.018} strokeOpacity="0.35" fill="none" />
      {/* Member dots */}
      {dots.map((d, i) => (
        <Circle key={i} cx={d.x} cy={d.y} r={r} fill={color} fillOpacity="0.85" />
      ))}
      {/* Central coin circle */}
      <Circle cx={cx} cy={cy} r={innerR} stroke={color} strokeWidth={size * 0.03} fill={color} fillOpacity="0.15" />
      {/* Rupee symbol */}
      <Path
        d={`M${cx - innerR * 0.4} ${cy - innerR * 0.4}h${innerR * 0.8}
            M${cx - innerR * 0.4} ${cy - innerR * 0.1}h${innerR * 0.8}
            M${cx - innerR * 0.1} ${cy - innerR * 0.4}v${innerR * 0.9}`}
        stroke={color}
        strokeWidth={size * 0.045}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </Svg>
  );
}
