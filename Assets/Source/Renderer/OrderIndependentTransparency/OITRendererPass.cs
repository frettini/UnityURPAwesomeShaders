using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

class OITRendererPass : ScriptableRenderPass
{
    LinkedListOIT LinkedList;

    public OITRendererPass()
    {
        renderPassEvent = RenderPassEvent.BeforeRenderingTransparents;
        LinkedList = new LinkedListOIT();
        RenderPipelineManager.beginContextRendering += PreRender;
    }

    private void PreRender(ScriptableRenderContext context, List<Camera> cameras)
    {
        CommandBuffer cmd = CommandBufferPool.Get("OITRendererPass");
        cmd.Clear();
        LinkedList.PreRender(cmd);
        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        CommandBuffer cmd = CommandBufferPool.Get("OITRendererPass");
        cmd.Clear();
        LinkedList.Execute(cmd,
                            renderingData.cameraData.renderer.cameraColorTargetHandle.nameID,
                            renderingData.cameraData.renderer.cameraColorTargetHandle.nameID);
        //LinkedList.Execute(cmd,
        //            renderingData.cameraData.renderer.cameraColorTarget,
        //            renderingData.cameraData.renderer.cameraColorTarget);
        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }

    public void CleanUp()
    {
        LinkedList.CleanUp();
        RenderPipelineManager.beginContextRendering -= PreRender;
    }
}
