// Fetches Skyline Aviation's assets for the Fleet Health map via the UI API
// GraphQL endpoint exposed by @salesforce/platform-sdk. This is the multi-framework
// equivalent of the guide's SOQL-over-data-SDK call (Part 10, Step 10.2), adapted to
// the GraphQL client the reactbasic scaffold ships with.
import { executeGraphQL } from './graphqlClient';
import type { HubAsset } from '@/lib/fleet';
import { HUB_COORDS } from '@/lib/fleet';

const ACCOUNT_NAME = 'Skyline Aviation';

const ASSETS_QUERY = /* GraphQL */ `
  query FleetAssets($accountName: String!) {
    uiapi {
      query {
        Asset(
          where: { Account: { Name: { eq: $accountName } } }
          first: 200
        ) {
          edges {
            node {
              Id
              Name { value }
              health_score__c { value }
              hub_location__c { value }
              maintenance_priority__c { value }
              Latitude { value }
              Longitude { value }
              Account { Name { value } }
            }
          }
        }
      }
    }
  }
`;

interface StringField { value: string | null }
interface NumberField { value: number | null }

interface AssetNode {
  Id: string;
  Name: StringField | null;
  health_score__c: NumberField | null;
  hub_location__c: StringField | null;
  maintenance_priority__c: StringField | null;
  Latitude: NumberField | null;
  Longitude: NumberField | null;
  Account: { Name: StringField | null } | null;
}

interface AssetsQueryResult {
  uiapi: { query: { Asset: { edges: { node: AssetNode }[] } } };
}

export async function fetchFleetAssets(): Promise<HubAsset[]> {
  const data = await executeGraphQL<AssetsQueryResult, { accountName: string }>(
    ASSETS_QUERY,
    { accountName: ACCOUNT_NAME }
  );

  // Track how many assets we've placed at each hub so co-located assets (the seed
  // data puts all of Skyline's assets in one hub) get a small fan-out offset
  // instead of stacking into a single unclickable marker.
  const hubSeen: Record<string, number> = {};

  return data.uiapi.query.Asset.edges
    .map(({ node }) => {
      const hubLocation = node.hub_location__c?.value ?? '';
      // Prefer the Asset's own geo fields; fall back to the hub-location lookup.
      const fallback = HUB_COORDS[hubLocation];
      let latitude = node.Latitude?.value ?? fallback?.[0] ?? 0;
      let longitude = node.Longitude?.value ?? fallback?.[1] ?? 0;

      // Only fan out when we're using the shared hub fallback (no real geo).
      if (node.Latitude?.value == null && fallback) {
        const index = hubSeen[hubLocation] ?? 0;
        hubSeen[hubLocation] = index + 1;
        const angle = (index * 2 * Math.PI) / 8; // up to 8 around a ring
        const ring = index === 0 ? 0 : 0.35; // ~0.35° ≈ 40km spread
        latitude += ring * Math.cos(angle);
        longitude += ring * Math.sin(angle);
      }

      return {
        id: node.Id,
        name: node.Name?.value ?? node.Id,
        accountName: node.Account?.Name?.value ?? ACCOUNT_NAME,
        hubLocation,
        healthScore: node.health_score__c?.value ?? 0,
        maintenancePriority: node.maintenance_priority__c?.value ?? '—',
        latitude,
        longitude,
      };
    })
    // Drop assets we can't place on the map (no geo + unknown hub).
    .filter((a) => a.latitude !== 0 || a.longitude !== 0);
}
