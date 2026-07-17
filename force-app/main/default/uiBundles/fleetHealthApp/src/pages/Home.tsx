import { useState } from 'react';
import AssetMap from '@/components/AssetMap';
import HubDetail from '@/components/HubDetail';
import { useAsyncData } from '@/hooks/useAsyncData';
import { fetchFleetAssets } from '@/api/fleetData';
import type { HubAsset } from '@/lib/fleet';

export default function Home() {
  const { data: assets, loading, error } = useAsyncData<HubAsset[]>(
    fetchFleetAssets,
    []
  );
  const [selected, setSelected] = useState<HubAsset | null>(null);

  return (
    <div className="flex h-[calc(100vh-4rem)] flex-col">
      <header className="border-b bg-slate-900 px-6 py-4 text-white">
        <h1 className="text-xl font-bold">Fleet Health Command Center</h1>
        <p className="mt-1 text-sm text-slate-400">
          Skyline Aviation — SEA Hub Network
        </p>
      </header>

      <div className="flex min-h-0 flex-1">
        <div className="min-w-0 flex-1">
          {loading && (
            <div className="flex h-full items-center justify-center text-gray-500">
              Loading fleet assets…
            </div>
          )}
          {error && (
            <div className="flex h-full items-center justify-center px-6 text-center text-red-600">
              Could not load assets: {error}
            </div>
          )}
          {!loading && !error && (
            <AssetMap
              assets={assets ?? []}
              selectedId={selected?.id ?? null}
              onSelect={setSelected}
            />
          )}
        </div>
        <aside className="w-80 overflow-y-auto border-l bg-white">
          <HubDetail asset={selected} />
        </aside>
      </div>
    </div>
  );
}
