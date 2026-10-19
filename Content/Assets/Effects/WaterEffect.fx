#include "Macros.hlsl"

float4x4 ModelToView;
float4x4 ModelToWorld;
float3x3 NormalToView;
float4x4 ModelToScreen;

float4 WaterTint;
float Time;
float3 LightPosition0;
float3 LightColor;

DECLARE_TEXTURE(WaterTexture, 0)
{
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU = Wrap;
    AddressV = Wrap;
};

struct VSInput
{
    float4 Position : POSITION0;
    float3 Normal : NORMAL0;
    float2 TextureCoords : TEXCOORD0;
};

struct V2P
{
    float4 Position : SV_Position;
    float2 TextureCoords : TEXCOORD0;
    float3 ViewPosition : TEXCOORD1;
    float3 ViewNormal : TEXCOORD2;
};

V2P WaterVertexShader(VSInput input)
{
    V2P output;
    float4 viewPosition = mul(input.Position, ModelToView);

    output.Position = mul(input.Position, ModelToScreen);
    output.ViewPosition = viewPosition.xyz;
    output.ViewNormal = mul(input.Normal, NormalToView);
    // The reused platform mesh has colour-atlas UVs. Project its world position
    // onto the horizontal plane so the water pattern spans the whole surface.
    output.TextureCoords = mul(input.Position, ModelToWorld).xz * 0.00025f;
    return output;
}

float4 WaterPixelShader(V2P input) : SV_TARGET0
{
    // Two differently scaled and directed samples avoid looking like one image
    // sliding rigidly across the surface.
    float2 uvA = input.TextureCoords * 3.0f + float2(Time * 0.025f, Time * 0.012f);
    float2 rotatedUV = float2(-input.TextureCoords.y, input.TextureCoords.x);
    float2 uvB = rotatedUV * 4.5f + float2(-Time * 0.018f, Time * 0.022f);

    float3 layerA = SAMPLE_TEXTURE(WaterTexture, uvA).rgb;
    float3 layerB = SAMPLE_TEXTURE(WaterTexture, uvB).rgb;
    float pattern = dot(lerp(layerA, layerB, 0.45f), float3(0.299f, 0.587f, 0.114f));

    float3 normal = normalize(input.ViewNormal);
    float3 viewDirection = normalize(-input.ViewPosition);
    float3 lightDirection = normalize(LightPosition0);
    float diffuse = 0.45f + 0.55f * saturate(dot(normal, lightDirection));
    float fresnel = pow(1.0f - saturate(dot(normal, viewDirection)), 3.0f);

    float3 deepColor = WaterTint.rgb * 0.55f;
    float3 shallowColor = WaterTint.rgb * 1.25f;
    float3 waterColor = lerp(deepColor, shallowColor, pattern);
    waterColor *= diffuse;
    waterColor += LightColor * fresnel * 0.22f;

    return float4(saturate(waterColor), WaterTint.a);
}

technique RenderWater
{
    pass P0
    {
        VertexShader = compile VS_SHADERMODEL WaterVertexShader();
        PixelShader = compile PS_SHADERMODEL WaterPixelShader();
    }
}
