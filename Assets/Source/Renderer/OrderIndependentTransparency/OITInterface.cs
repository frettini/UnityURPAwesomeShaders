using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public interface IOrderIndependentTransparency
{
    public void PreRender(CommandBuffer cmd);
    public void Execute(ScriptableRenderContext context, CommandBuffer cmd, ref RenderingData renderingData, RTHandle src, RTHandle dest);
    public void CleanUp();
}
