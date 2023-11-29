using UnityEngine;
using UnityEngine.Rendering.Universal;

public class OITRendererFeature : ScriptableRendererFeature
{
    private OITRendererPass oitRendererPass;
    private ScriptableRenderPassInput requirements = ScriptableRenderPassInput.Color;
    public override void Create()
    {
        oitRendererPass?.CleanUp();
        oitRendererPass = new OITRendererPass();
        
        ScriptableRenderPassInput modifiedRequirements = requirements;
        oitRendererPass.ConfigureInput(modifiedRequirements);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        //Calling ConfigureInput with the ScriptableRenderPassInput.Color argument ensures that the opaque texture is available to the Render Pass
        oitRendererPass.ConfigureInput(ScriptableRenderPassInput.Color);

        renderer.EnqueuePass(oitRendererPass);
    }

    protected override void Dispose(bool disposing)
    {
        oitRendererPass.CleanUp();
    }
}
