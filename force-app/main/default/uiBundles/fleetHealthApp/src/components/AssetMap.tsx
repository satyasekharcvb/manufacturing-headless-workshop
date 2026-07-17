import { MapContainer, TileLayer, CircleMarker, Tooltip } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';
import type { HubAsset } from '@/lib/fleet';
import { healthColor } from '@/lib/fleet';

interface AssetMapProps {
  assets: HubAsset[];
  selectedId: string | null;
  onSelect: (asset: HubAsset) => void;
}

export default function AssetMap({ assets, selectedId, onSelect }: AssetMapProps) {
  // Center on the mean of the asset coordinates so the view fits the data
  // (Hong Kong for the Skyline seed, SEA cities for the broader hub network).
  const center: [number, number] = assets.length
    ? [
        assets.reduce((s, a) => s + a.latitude, 0) / assets.length,
        assets.reduce((s, a) => s + a.longitude, 0) / assets.length,
      ]
    : [5, 110];

  return (
    <MapContainer center={center} zoom={6} className="h-full w-full">
      <TileLayer
        // CARTO Voyager renders place labels in English/Latin script, so hubs like
        // Hong Kong show English names instead of the local script that the default
        // OpenStreetMap tiles use.
        url="https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png"
        subdomains="abcd"
        attribution="© OpenStreetMap contributors © CARTO"
      />
      {assets.map((asset) => {
        const isSelected = asset.id === selectedId;
        return (
          <CircleMarker
            key={asset.id}
            center={[asset.latitude, asset.longitude]}
            radius={isSelected ? 16 : 11}
            pathOptions={{
              fillColor: healthColor(asset.healthScore),
              color: isSelected ? '#1e293b' : '#fff',
              weight: isSelected ? 4 : 2,
              fillOpacity: 0.9,
            }}
            eventHandlers={{ click: () => onSelect(asset) }}
          >
            <Tooltip direction="top">
              <strong>{asset.hubLocation}</strong> — {asset.healthScore}%
            </Tooltip>
          </CircleMarker>
        );
      })}
    </MapContainer>
  );
}
