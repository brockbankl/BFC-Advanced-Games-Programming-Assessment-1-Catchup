#include "Macros.hlsl"

// Matrices supplied by SceneRenderer for the current model mesh.
float4x4 ModelToLight0;
float4x4 ModelToLight1;
float4x4 ModelToView;
float3x3 NormalToView;
float4x4 ModelToScreen;

// Surface and lighting values supplied by C#.
float4 Color;
float3 LightPosition0;
float3 LightColor;
float AmbientIntensity;
float SpecularIntensity;
float Shininess;

// Values unique to the cel-shading lesson.
float LightBands;
float SpecularThreshold;
float RimStrength;
float RimPower;
float3 RimColor;

// Existing shadow-map values supplied by SceneRenderer.
float EdgeFadeScale;
float2 ShadowMask;

static const int ShadowSamples = 64;

DECLARE_TEXTURE(ShadowMap0, 0)
{
    MinFilter = linear;
    MagFilter = linear;
    MipFilter = linear;
    AddressU = Clamp;
    AddressV = Clamp;
};

DECLARE_TEXTURE(ShadowMap1, 1)
{
    MinFilter = linear;
    MagFilter = linear;
    MipFilter = linear;
    AddressU = Clamp;
    AddressV = Clamp;
};

DECLARE_TEXTURE(Texture, 3)
{
    Filter = ANISOTROPIC;
    MaxAnisotropy = 16;
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
    float4 ViewPosition : TEXCOORD1;
    float3 ViewNormal : TEXCOORD2;
    float2 SMPosition0 : TEXCOORD3;
    float2 SMPosition1 : TEXCOORD4;
    float SMDepth0 : TEXCOORD5;
    float SMDepth1 : TEXCOORD6;
    float4 Color : COLOR0;
};

float2 RandomOffset(float4 seed)
{
    float dotProduct = dot(seed, float4(12.9898, 78.233, 45.164, 94.673));
    return float2(
        frac(sin(dotProduct) * 43758.5453),
        frac(sin(dotProduct) * 68654.4865));
}

float CalculateShadow(V2P input)
{
    float shadowScalar = 1.0f;

    for (int i = 0; i < ShadowSamples; i++)
    {
        float4 seed = float4(i, input.ViewPosition.xyz);
        float2 jitter = RandomOffset(seed) / 500.0f;

        float2 samplePosition0 = input.SMPosition0 + jitter;
        float2 edgeDistance0 = min(samplePosition0, 1.0f - samplePosition0);
        float edgeFade0 = saturate(min(edgeDistance0.x, edgeDistance0.y) * EdgeFadeScale);
        float sampledDepth0 = SAMPLE_TEXTURE(ShadowMap0, samplePosition0).x;
        if (sampledDepth0 < input.SMDepth0)
            shadowScalar -= ShadowMask.x * (1.0f / ShadowSamples) * edgeFade0;

        float2 samplePosition1 = input.SMPosition1 + jitter;
        float2 edgeDistance1 = min(samplePosition1, 1.0f - samplePosition1);
        float edgeFade1 = saturate(min(edgeDistance1.x, edgeDistance1.y) * EdgeFadeScale);
        float sampledDepth1 = SAMPLE_TEXTURE(ShadowMap1, samplePosition1).x;
        if (sampledDepth1 < input.SMDepth1)
            shadowScalar -= ShadowMask.y * (1.0f / ShadowSamples) * edgeFade1;
    }

    return saturate(shadowScalar);
}

float QuantizeLight(float value)
{
    // Four bands produce the levels 0, 1/3, 2/3, and 1.
    float intervals = max(LightBands - 1.0f, 1.0f);
    return floor(saturate(value) * intervals + 0.5f) / intervals;
}

float4 ApplyCelLighting(V2P input, float4 surfaceColor)
{
    float3 normal = normalize(input.ViewNormal);
    float3 lightDirection = normalize(LightPosition0);
    float3 viewDirection = normalize(-input.ViewPosition.xyz);

    float diffuseAmount = saturate(dot(normal, lightDirection));
    float bandedDiffuse = QuantizeLight(diffuseAmount);

    float3 reflectedLight = reflect(-lightDirection, normal);
    float specularAmount = pow(saturate(dot(viewDirection, reflectedLight)), Shininess);
    float hardSpecular = step(SpecularThreshold, specularAmount) * SpecularIntensity;

    float rimAmount = 1.0f - saturate(dot(viewDirection, normal));
    rimAmount = saturate(pow(rimAmount, RimPower) * RimStrength);

    float shadow = CalculateShadow(input);
    float3 ambient = surfaceColor.rgb * AmbientIntensity;
    float3 diffuse = surfaceColor.rgb * LightColor * bandedDiffuse;
    float3 specular = LightColor * hardSpecular;
    float3 rim = RimColor * rimAmount;

    float3 finalColor = ambient + shadow * (diffuse + specular) + rim;
    return float4(saturate(finalColor), surfaceColor.a);
}

V2P CelVertexShader(VSInput input)
{
    V2P output;

    output.ViewPosition = mul(input.Position, ModelToView);
    output.Position = mul(input.Position, ModelToScreen);
    output.ViewNormal = mul(input.Normal, NormalToView);
    output.TextureCoords = input.TextureCoords;
    output.Color = Color;

    float4 lightPosition0 = mul(input.Position, ModelToLight0);
    output.SMPosition0 = mad(
        lightPosition0.xy / lightPosition0.w,
        0.5f,
        float2(0.5f, 0.5f));
    output.SMPosition0.y = 1.0f - output.SMPosition0.y;
    output.SMDepth0 = lightPosition0.z / lightPosition0.w;

    float4 lightPosition1 = mul(input.Position, ModelToLight1);
    output.SMPosition1 = mad(
        lightPosition1.xy / lightPosition1.w,
        0.5f,
        float2(0.5f, 0.5f));
    output.SMPosition1.y = 1.0f - output.SMPosition1.y;
    output.SMDepth1 = lightPosition1.z / lightPosition1.w;

    return output;
}

float4 CelPixelShader(V2P input) : SV_TARGET0
{
    float4 surfaceColor = input.Color * SAMPLE_TEXTURE(Texture, input.TextureCoords);
    return ApplyCelLighting(input, surfaceColor);
}

technique RenderCelShaded
{
    pass P0
    {
        VertexShader = compile VS_SHADERMODEL CelVertexShader();
        PixelShader = compile PS_SHADERMODEL CelPixelShader();
    }
}
