
using UnityEngine;
using static Unity.VisualScripting.Member;

public class TransparentPlaneAnim : MonoBehaviour
{
    [SerializeField]
    public float rotationSpeed = 0.1f;

    private readonly int LayerHeightPropertyId = Shader.PropertyToID("_Height");
    Material mat;
    private float time = 0.0f;
    private float[] targets = { 0.1f, 2.0f, 4.0f, 2.0f };
    private int index = 0;

    // Start is called before the first frame update
    void Awake()
    {
        mat = GetComponent<Renderer>().material;
    }

    // Update is called once per frame
    void Update()
    {
        time += Time.deltaTime; 
        transform.Rotate(new Vector3(0.0f, rotationSpeed, 0.0f));
        //float height = Mathf.Cos(Time.time*0.4f + 3.14f)*2.0f + 2.0f;

        if(time > 3.0f)
        {
            time = 0.0f;
            index = (index + 1) % targets.Length;
        }

        float source = targets[index];
        float target = targets[(index+1) % targets.Length];
        float height = Mathf.Lerp(source, target, time / 2.0f);
        mat.SetFloat(LayerHeightPropertyId, height);
        
    }
}
