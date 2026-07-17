import { useEffect, useRef } from 'react';
import { embedAgentforceClient } from '@salesforce/agentforce-conversation-client';

// The Renewal QBR Assistant agent, activated in the org. Swap this id when
// deploying to a different org (find it in Setup → Agents, or via the
// BotDefinition / bot record). Passed to ACC as `agentId`.
const AGENT_ID = '0XxWU000002kyPp0AI';
const AGENT_LABEL = 'Renewal QBR Assistant';

/**
 * Embeds the Agentforce Conversation Client (ACC), built on Lightning Out 2.0,
 * into the Fleet Health app. Because the bundle is hosted inside the org, ACC
 * reuses the logged-in session — we pass `salesforceOrigin` (the org's
 * my.salesforce.com origin) so LO 2.0 can bootstrap against it.
 *
 * Rendered as a floating action button so it overlays the map without
 * consuming layout space; Priya opens it after reviewing a hub's health score.
 */
export default function AgentChat() {
  const containerRef = useRef<HTMLDivElement>(null);
  const startedRef = useRef(false);

  useEffect(() => {
    if (startedRef.current || !containerRef.current) return;
    startedRef.current = true;

    const { loApp } = embedAgentforceClient({
      container: containerRef.current,
      // The org's instance URL (e.g. https://<mydomain>.my.salesforce.com).
      // Per the ACC guide this is the only org-specific value ACC needs; set it
      // in .env.local for local dev and via the build env when hosted.
      salesforceOrigin: import.meta.env.VITE_SF_INSTANCE_URL,
      agentforceClientConfig: {
        agentId: AGENT_ID,
        agentLabel: AGENT_LABEL,
        renderingConfig: {
          mode: 'floating',
          showHeaderIcon: true,
        },
        floatingButtonLabel: 'Ask Renewal QBR Assistant',
      },
      onError: (err) => {
        // Surface bootstrap/iframe errors in the console for diagnosis rather
        // than failing silently (ACC hides the embed until it's ready).
        console.error('[AgentChat] ACC error', err);
      },
    });

    return () => {
      // Tear down the Lightning Out app on unmount so a re-mount (route change,
      // HMR) doesn't stack multiple embeds. LightningOutApplication exposes
      // destroy(); guard in case the shape changes across LO 2.0 versions.
      try {
        (loApp as unknown as { destroy?: () => void })?.destroy?.();
      } catch {
        /* no-op: destroy is best-effort */
      }
      startedRef.current = false;
    };
  }, []);

  return <div ref={containerRef} data-testid="agentforce-chat" />;
}
