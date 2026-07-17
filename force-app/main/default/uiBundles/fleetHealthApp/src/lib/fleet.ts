// Fleet Health domain helpers: hub coordinates and health-score color scale.
//
// Coordinates and the color thresholds mirror the workshop guide's AssetMap
// (Part 10, Step 10.3). The Asset's own Latitude/Longitude are used when present;
// otherwise we fall back to the hub-location lookup below.

export interface HubAsset {
  id: string;
  name: string;
  accountName: string;
  hubLocation: string;
  healthScore: number;
  maintenancePriority: string;
  latitude: number;
  longitude: number;
}

// Hub coordinates. Hong Kong is where WorkshopDataSetup.setupSkylineDemo seeds
// Skyline Aviation's assets; the SEA cities are kept for any org whose data uses
// the guide's broader SEA hub network.
export const HUB_COORDS: Record<string, [number, number]> = {
  'Hong Kong': [22.3193, 114.1694],
  Singapore: [1.3521, 103.8198],
  'Kuala Lumpur': [3.139, 101.6869],
  Jakarta: [-6.2088, 106.8456],
  Manila: [14.5995, 120.9842],
  Bangkok: [13.7563, 100.5018],
};

// Green >= 90, yellow >= 80, red below 80 — matches the guide's healthColor().
export function healthColor(score: number): string {
  if (score >= 90) return '#22c55e';
  if (score >= 80) return '#eab308';
  return '#ef4444';
}

export function healthStatus(score: number): string {
  if (score >= 90) return 'Healthy';
  if (score >= 80) return 'Watch';
  return 'At Risk';
}
