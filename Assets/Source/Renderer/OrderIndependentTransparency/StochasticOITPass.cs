using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace StochasticTransparency
{
    class TransmittancePass : ScriptableRenderPass
    {
        private FilteringSettings filteringSettings;
        private readonly LayerMask layerMask = -1;
        private RTHandle transmittanceRT;

        private readonly ShaderTagId transmittanceTagId = new ShaderTagId("ST_Transmittance");
        private readonly int transmittanceId = Shader.PropertyToID("_Transmittance");

        public TransmittancePass()
        {
            profilingSampler = new ProfilingSampler("TransmittancePass");
            renderPassEvent = RenderPassEvent.BeforeRenderingTransparents;
            filteringSettings = new FilteringSettings(RenderQueueRange.all, layerMask.value);
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            // Multisample render target.
            RenderTextureDescriptor desc = renderingData.cameraData.cameraTargetDescriptor;
            //desc.msaaSamples = 1;
            //TODO use a single channel format
            //desc.colorFormat = RenderTextureFormat.ARGB32;
            desc.depthBufferBits = 0;
            RenderingUtils.ReAllocateIfNeeded(ref transmittanceRT, desc, FilterMode.Point, TextureWrapMode.Clamp, name: "transmittanceRT");

            ConfigureTarget(transmittanceRT);
            ConfigureClear(ClearFlag.Color, Color.white);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get("Transmittance Pass");

            // sorting doesn't matter in this stage
            DrawingSettings drawSettings = CreateDrawingSettings(transmittanceTagId, ref renderingData, SortingCriteria.None);

            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();

            using (new ProfilingScope(cmd, profilingSampler))
            {
                context.DrawRenderers(renderingData.cullResults, ref drawSettings, ref filteringSettings);
            }
                
            // not sure whether this should go in a setup stage instead?
            cmd.SetGlobalTexture(transmittanceId, transmittanceRT);
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
           
            CommandBufferPool.Release(cmd);
        }

        public void CleanUp()
        {
            transmittanceRT?.Release();
        }
    }

    class StochasticDepthPass : ScriptableRenderPass
    {
        private FilteringSettings filteringSettings;
        private readonly LayerMask layerMask = -1;
        private RTHandle stochasticDepthRT;
        private readonly ShaderTagId stochasticDepthTagId = new ShaderTagId("ST_DepthPass");
        private readonly int stochasticDepthId = Shader.PropertyToID("_StochasticDepth");

        public StochasticDepthPass()
        {
            profilingSampler = new ProfilingSampler("StochasticDepthPass");
            filteringSettings = new FilteringSettings(RenderQueueRange.all, layerMask.value);
            renderPassEvent = RenderPassEvent.BeforeRenderingTransparents;
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            RenderTextureDescriptor desc = renderingData.cameraData.cameraTargetDescriptor;
            //desc.msaaSamples = 1;
            //desc.colorFormat = RenderTextureFormat.ARGB32;

            // TODO: probably reduce to 24 bits.
            //desc.depthBufferBits = 32;
            //RenderingUtils.ReAllocateIfNeeded(ref stochasticDepthRT, desc, FilterMode.Point, TextureWrapMode.Clamp, name: "stochasticDepthRT");

            
            // setup depth target
            ConfigureTarget(renderingData.cameraData.renderer.cameraColorTargetHandle, renderingData.cameraData.renderer.cameraDepthTargetHandle);
            //ConfigureClear(ClearFlag.Color, Color.clear);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get("StochasticDepthPass");
            cmd.Clear();

            using (new ProfilingScope(cmd, profilingSampler))
            {
                var sortingSettings = new SortingSettings(renderingData.cameraData.camera);
                DrawingSettings drawSettings = CreateDrawingSettings(stochasticDepthTagId, ref renderingData, SortingCriteria.None);
                context.DrawRenderers(renderingData.cullResults, ref drawSettings, ref filteringSettings);
            }

            // not sure whether this should go in a setup stage instead?
            cmd.SetGlobalTexture(stochasticDepthId, stochasticDepthRT);
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();

            CommandBufferPool.Release(cmd);
        }

        public void CleanUp()
        {
            stochasticDepthRT?.Release();
        }
    }

    class AccumulationPass : ScriptableRenderPass
    {
        private FilteringSettings filteringSettings;
        private readonly LayerMask layerMask = -1;
        private RTHandle stochasticColorRT;
        private readonly ShaderTagId stochasticTagId = new ShaderTagId("ST_Accumulation");
        private readonly int stochasticColorId = Shader.PropertyToID("_ST_ColorAccumulation");

        public AccumulationPass()
        {
            profilingSampler = new ProfilingSampler("StochasticOITPass");
            filteringSettings = new FilteringSettings(RenderQueueRange.all, layerMask.value);
            renderPassEvent = RenderPassEvent.BeforeRenderingTransparents;

        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            // multisampled
            RenderTextureDescriptor desc = renderingData.cameraData.cameraTargetDescriptor;
            //desc.msaaSamples = 1;
            //desc.colorFormat = RenderTextureFormat.ARGB32;
            desc.depthBufferBits = 0;
            RenderingUtils.ReAllocateIfNeeded(ref stochasticColorRT, desc, FilterMode.Point, TextureWrapMode.Clamp, name: "stochasticColorRT");

            ConfigureTarget(stochasticColorRT, renderingData.cameraData.renderer.cameraDepthTargetHandle);
            ConfigureClear(ClearFlag.Color, Color.clear);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get("StochasticColorPass");
            cmd.Clear();

            using (new ProfilingScope(cmd, profilingSampler))
            {
                var sortingSettings = new SortingSettings(renderingData.cameraData.camera);
                DrawingSettings drawSettings = CreateDrawingSettings(stochasticTagId, ref renderingData, SortingCriteria.None);
                context.DrawRenderers(renderingData.cullResults, ref drawSettings, ref filteringSettings);
            }

            // not sure whether this should go in a setup stage instead?
            cmd.SetGlobalTexture(stochasticColorId, stochasticColorRT);
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();

            CommandBufferPool.Release(cmd);
        }

        public void CleanUp()
        {
            stochasticColorRT?.Release();
        }
    }

    class ResolveTransparencyPass : ScriptableRenderPass
    {
        private Material resolveMat;
        private int resolvePassId = 3;
        private RTHandle cameraColorTarget;
        //private FilteringSettings filteringSettings;
        //private readonly LayerMask layerMask = -1;
        //private readonly ShaderTagId stochasticTagId = new ShaderTagId("StochasticTransparency");

        public ResolveTransparencyPass(Material mat)
        {
            resolveMat = mat;
            profilingSampler = new ProfilingSampler("ResolveOITPass");
            //filteringSettings = new FilteringSettings(RenderQueueRange.all, layerMask.value);
            renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
        }

        public void SetTarget(RTHandle colorHandle)
        {
            cameraColorTarget = colorHandle;
        }


        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            ConfigureTarget(cameraColorTarget);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get("ResolveStochasticPass");

            if (renderingData.cameraData.isPreviewCamera)
            {
                return;
            }

            using (new ProfilingScope(cmd, profilingSampler))
            {
                //var sortingSettings = new SortingSettings(renderingData.cameraData.camera);
                //DrawingSettings drawSettings = CreateDrawingSettings(stochasticTagId, ref renderingData, SortingCriteria.None);
                //context.DrawRenderers(renderingData.cullResults, ref drawSettings, ref filteringSettings);

                //Blit();
                Blitter.BlitCameraTexture(cmd,
                                            renderingData.cameraData.renderer.cameraColorTargetHandle,
                                            renderingData.cameraData.renderer.cameraColorTargetHandle,
                                            resolveMat, resolvePassId);
            }

            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
            CommandBufferPool.Release(cmd);
        }

        public void CleanUp()
        {
            // nothing to cleanup for this one?
        }
    }

}