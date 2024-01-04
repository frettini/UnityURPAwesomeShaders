using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

class LinkedListOIT : IOrderIndependentTransparency
{
    private int screenHeight, screenWidth;
    private readonly int maxNumLayers = 16;

    private ComputeBuffer startOffsetBuffer;
    private readonly int startOffsetBufferId;
    private ComputeBuffer fragmentLLBuffer;
    private readonly int fragmentLLBufferId;

    private Material LLRendererMaterial;

    private readonly ComputeShader LLUtilsCompute;
    private readonly int initStartOffsetKernelId;
    private int dispatchGroupSizeX, dispatchGroupSizeY;

    public LinkedListOIT()
    {
        startOffsetBufferId = Shader.PropertyToID("startOffsetBuffer");
        fragmentLLBufferId = Shader.PropertyToID("fragmentLLBuffer");

        LLUtilsCompute = Resources.Load<ComputeShader>("OITLLUtils");
        initStartOffsetKernelId = LLUtilsCompute.FindKernel("InitStartOffsetBuffer");

        SetupResources();
    }

     public void PreRender(CommandBuffer cmd)
    {
        if (Screen.width != screenWidth || Screen.height != screenHeight || LLRendererMaterial == null)
        {
            SetupResources();
        }

        LLUtilsCompute.Dispatch(initStartOffsetKernelId, dispatchGroupSizeX, dispatchGroupSizeY, 1);

        cmd.SetRandomWriteTarget(1, fragmentLLBuffer);
        cmd.SetRandomWriteTarget(2, startOffsetBuffer);
    }

    public void Execute(ScriptableRenderContext context, CommandBuffer cmd, ref RenderingData renderingData, RTHandle src, RTHandle dest)
    {
        cmd.ClearRandomWriteTargets();

        if(LLRendererMaterial == null 
            || renderingData.cameraData.isPreviewCamera)
        {
            return;
        }

        LLRendererMaterial.SetBuffer(startOffsetBufferId, startOffsetBuffer);
        LLRendererMaterial.SetBuffer(fragmentLLBufferId, fragmentLLBuffer);

        Blitter.BlitCameraTexture(cmd, 
            src, //renderingData.cameraData.renderer.cameraColorTargetHandle, 
            dest, //renderingData.cameraData.renderer.cameraColorTargetHandle,
            LLRendererMaterial, 0);
    }

    public void CleanUp()
    {
        startOffsetBuffer?.Dispose();
        fragmentLLBuffer?.Dispose();
    }

    private void SetupResources()
    {
        CleanUp();

        if(LLRendererMaterial == null)
        {
            LLRendererMaterial = new Material(Resources.Load<Shader>("RenderLLOIT"));
        }

        screenHeight = Screen.height;
        screenWidth = Screen.width;
        
        int bufferSize = screenHeight * screenWidth * maxNumLayers;
        int stride = sizeof(uint) * 3;
        fragmentLLBuffer = new ComputeBuffer(bufferSize, stride, ComputeBufferType.Counter);

        bufferSize = screenHeight * screenWidth ;
        stride = sizeof(uint);
        startOffsetBuffer = new ComputeBuffer(bufferSize, stride, ComputeBufferType.Raw);

        // init startOffsetBuffer to -1.
        LLUtilsCompute.SetInt("screenWidth", screenWidth);
        LLUtilsCompute.SetBuffer(initStartOffsetKernelId, startOffsetBufferId, startOffsetBuffer);
        dispatchGroupSizeX = Mathf.CeilToInt(screenWidth / 32.0f);
        dispatchGroupSizeY = Mathf.CeilToInt(screenHeight / 32.0f);
    }
}