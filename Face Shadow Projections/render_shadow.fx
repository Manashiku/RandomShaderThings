float4x4 mmd_wvp : WORLDVIEWPROJECTION;
float4x4 mmd_w   : WORLD;

#define FACE_SHADOW_SOFTNESS 0.025
float4x4 head_bone : CONTROLOBJECT < string name = "(self)"; string item = "light_link"; >;
float4x4 light_bone : CONTROLOBJECT < string name = "(self)"; string item = "light_rotate"; >;
float3 light_direction : DIRECTION < string Object = "Light"; >;

texture2D diffuse_texture : MATERIALTEXTURE;
sampler2D diffuse_sampler = sampler_state
{
    texture = <diffuse_texture>;
    FILTER = ANISOTROPIC;
    ADDRESSV = WRAP;
    ADDRESSU = WRAP;
};
struct vs_in
{
    float4 pos : POSITION;
    float3 normal : NORMAL;
    float2 uv    : TEXCOORD0;
};

struct vs_out
{
    float4 pos : POSITION;
    float3 normal : TEXCOORD0;
    float2 uv : TEXCOORD1;
};

vs_out vs_shadow(vs_in i)
{
    vs_out o;
    o.pos = mul(i.pos, mmd_wvp);
    o.normal = mul(i.normal, (float3x3)mmd_w);
    o.uv = i.uv;
    return o;
}

float4 ps_shadow(vs_out i) : COLOR0
{
    float3 normal = normalize(i.normal);
    float4 color = (float4)1.0f;

    float ndotl = saturate(dot(normal, -light_direction) * 0.5f + 0.5f);
    color.xyz = (float3)ndotl;
    return color;
}


technique model_ss < string MMDPass = "object_ss"; >
{
    pass draw_model
    {
        VertexShader = compile vs_3_0 vs_shadow(); 
        PixelShader = compile ps_3_0 ps_shadow();
    }
}

technique mdoe < string MMDPass = "object"; >
{
    pass draw_model 
    { 
        VertexShader = compile vs_3_0 vs_shadow(); 
        PixelShader = compile ps_3_0 ps_shadow(); 
    }
}

technique empty_edge < string MMDPass = "edge";> {}
