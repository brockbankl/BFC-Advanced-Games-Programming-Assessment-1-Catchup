// Week 3: a screen-space effect that changes the completed scene image.
#include "Macros.hlsl"

BEGIN_CONSTANTS
float Levels;
END_CONSTANTS

DECLARE_TEXTURE(ScreenTexture, 0)
{
    MipFilter = NONE;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    AddressU = Clamp;
    AddressV = Clamp;
};

struct VertexShaderOutput
{
    float4 Position : SV_POSITION;
    float4 Color : Color0;
    float2 TexCoord : TEXCOORD0;
};

float4 PosterizePS(VertexShaderOutput input) : SV_TARGET0
{
    float4 color = SAMPLE_TEXTURE(ScreenTexture, input.TexCoord);
    // Round each RGB channel to one of Levels evenly spaced values.
    // At least two levels avoids division by zero; higher values retain more detail.
    float steps = max(Levels, 2.0f) - 1.0f;
    float3 bands = floor(saturate(color.rgb) * steps + 0.5f) / steps;
    return float4(bands, color.a);
}

technique Posterize
{
    pass Pass1
    {
        PixelShader = compile PS_SHADERMODEL PosterizePS();
    }
}
