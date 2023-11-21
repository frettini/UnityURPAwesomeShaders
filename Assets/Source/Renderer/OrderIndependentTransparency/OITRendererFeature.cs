using UnityEngine;
using UnityEngine.Rendering.Universal;

public class OITRendererFeature : ScriptableRendererFeature
{
    private OITRendererPass oitRendererPass;
    public override void Create()
    {
        oitRendererPass?.CleanUp();
        oitRendererPass = new OITRendererPass();    
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        // Unity does not provide an example how to perform a fullscreen Blit that works in scene view
        // Hence only Blit in Game view for now
        if (renderingData.cameraData.cameraType != CameraType.Game)
            return;
        //Calling ConfigureInput with the ScriptableRenderPassInput.Color argument ensures that the opaque texture is available to the Render Pass
        oitRendererPass.ConfigureInput(ScriptableRenderPassInput.Color);

        renderer.EnqueuePass(oitRendererPass);
    }

    protected override void Dispose(bool disposing)
    {
        oitRendererPass.CleanUp();
    }
}
