using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

class OITRendererPass : ScriptableRenderPass
{
    IOrderIndependentTransparency OrderIndependentTransparency;

    public OITRendererPass()
    {
        renderPassEvent = RenderPassEvent.BeforeRenderingTransparents;
        OrderIndependentTransparency = new LinkedListOIT();
        RenderPipelineManager.beginContextRendering += PreRender;
    }

    private void PreRender(ScriptableRenderContext context, List<Camera> cameras)
    {
        CommandBuffer cmd = CommandBufferPool.Get("OITRendererPass");
        cmd.Clear();
        OrderIndependentTransparency.PreRender(cmd);
        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }


    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        CommandBuffer cmd = CommandBufferPool.Get("OITRendererPass");
        cmd.Clear();
        OrderIndependentTransparency.Execute(context, cmd, ref renderingData,
                            renderingData.cameraData.renderer.cameraColorTargetHandle,
                            renderingData.cameraData.renderer.cameraColorTargetHandle);
        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }

    public void CleanUp()
    {
        OrderIndependentTransparency.CleanUp();
        RenderPipelineManager.beginContextRendering -= PreRender;
    }
}
