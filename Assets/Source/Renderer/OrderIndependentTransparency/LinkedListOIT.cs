using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

class LinkedListOIT
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
        LLRendererMaterial = new Material(Resources.Load<Shader>("RenderLLOIT"));
        startOffsetBufferId = Shader.PropertyToID("startOffsetBuffer");
        fragmentLLBufferId = Shader.PropertyToID("fragmentLLBuffer");

        LLUtilsCompute = Resources.Load<ComputeShader>("OITLLUtils");
        initStartOffsetKernelId = LLUtilsCompute.FindKernel("InitStartOffsetBuffer");

        SetupResources();
    }

     public void PreRender(CommandBuffer cmd)
    {
        if (Screen.width != screenWidth || Screen.height != screenHeight)
        {
            SetupResources();
        }

        LLUtilsCompute.Dispatch(initStartOffsetKernelId, dispatchGroupSizeX, dispatchGroupSizeY, 1);

        cmd.SetRandomWriteTarget(1, fragmentLLBuffer);
        cmd.SetRandomWriteTarget(2, startOffsetBuffer);
    }

    public void Execute(CommandBuffer cmd, ref RenderingData renderingData, RenderTargetIdentifier src, RenderTargetIdentifier dest)
    {
        cmd.ClearRandomWriteTargets();

        if(LLRendererMaterial == null)
        {
            return;
        }

        LLRendererMaterial.SetBuffer(startOffsetBufferId, startOffsetBuffer);
        LLRendererMaterial.SetBuffer(fragmentLLBufferId, fragmentLLBuffer);

        cmd.Blit( src, dest, LLRendererMaterial);
    }

    public void CleanUp()
    {
        startOffsetBuffer?.Dispose();
        fragmentLLBuffer?.Dispose();
    }

    private void SetupResources()
    {
        CleanUp();

        screenHeight = Screen.height;
        screenWidth = Screen.width;
        
        int bufferSize = screenHeight * screenWidth * maxNumLayers;
        //Debug.Log(screenHeight);
        //Debug.Log(screenWidth);
        //Debug.Log(maxNumLayers);
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