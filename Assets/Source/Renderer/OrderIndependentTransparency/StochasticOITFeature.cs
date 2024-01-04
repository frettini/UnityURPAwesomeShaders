using UnityEngine;
using UnityEngine.Rendering.Universal;
using static UnityEngine.XR.XRDisplaySubsystem;

namespace StochasticTransparency
{
    public class StochasticOITFeature : ScriptableRendererFeature
    {
        public Material stochasticTransparencyMaterial;

        private TransmittancePass transmittancePass;
        private AccumulationPass accumulationPass;
        private StochasticDepthPass stochasticDepthPass;
        private ResolveTransparencyPass resolvePass;
        private ScriptableRenderPassInput requirements = ScriptableRenderPassInput.Color;
        public override void Create()
        {
            transmittancePass?.CleanUp();
            stochasticDepthPass?.CleanUp();
            accumulationPass?.CleanUp();
            resolvePass?.CleanUp();

            transmittancePass = new TransmittancePass();
            accumulationPass = new AccumulationPass();
            stochasticDepthPass = new StochasticDepthPass();
            resolvePass = new ResolveTransparencyPass(stochasticTransparencyMaterial);
        }

        public override void SetupRenderPasses(ScriptableRenderer renderer,
                                        in RenderingData renderingData)
        {
            transmittancePass.ConfigureInput(ScriptableRenderPassInput.Color);
            accumulationPass.ConfigureInput(ScriptableRenderPassInput.Depth);
            // Calling ConfigureInput with the ScriptableRenderPassInput.Color argument
            // ensures that the opaque texture is available to the Render Pass.
            resolvePass.ConfigureInput(ScriptableRenderPassInput.Color);
            resolvePass.SetTarget(renderer.cameraColorTargetHandle);
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            //Calling ConfigureInput with the ScriptableRenderPassInput.Color argument ensures that the opaque texture is available to the Render Pass
            //transmittancePass.ConfigureInput(ScriptableRenderPassInput.Color);

            renderer.EnqueuePass(transmittancePass);
            renderer.EnqueuePass(stochasticDepthPass);
            renderer.EnqueuePass(accumulationPass);
            renderer.EnqueuePass(resolvePass);
        }

        protected override void Dispose(bool disposing)
        {
            transmittancePass.CleanUp();
            stochasticDepthPass.CleanUp();
            accumulationPass.CleanUp();
            resolvePass?.CleanUp(); 
        }
    }
}