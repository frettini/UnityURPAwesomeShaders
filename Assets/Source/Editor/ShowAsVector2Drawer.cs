using UnityEngine;
using UnityEditor;

//https://stackoverflow.com/questions/60899301/expose-float2-vector2-property-from-shader-to-unity-material-inspector
/// <summary>
/// Draws a vector2 field for vector properties.
/// Usage: [ShowAsVector2] _Vector2("Vector 2", Vector) = (0,0,0,0)
/// </summary>
public class ShowAsVector2Drawer : MaterialPropertyDrawer
{
    public override void OnGUI(Rect position, MaterialProperty prop, GUIContent label, MaterialEditor editor)
    {
        if (prop.type == MaterialProperty.PropType.Vector)
        {
            EditorGUIUtility.labelWidth = 0f;
            EditorGUIUtility.fieldWidth = 0f;

            if (!EditorGUIUtility.wideMode)
            {
                EditorGUIUtility.wideMode = true;
                EditorGUIUtility.labelWidth = EditorGUIUtility.currentViewWidth - 212;
            }

            EditorGUI.BeginChangeCheck();
            EditorGUI.showMixedValue = prop.hasMixedValue;
            Vector4 vec = EditorGUI.Vector2Field(position, label, prop.vectorValue);
            if (EditorGUI.EndChangeCheck())
            {
                prop.vectorValue = vec;
            }
        }
        else
            editor.DefaultShaderProperty(prop, label.text);

    }
}