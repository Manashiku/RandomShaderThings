#define use_projected_shadow




float4x4 mmd_wvp : WORLDVIEWPROJECTION;
float4x4 mmd_w   : WORLD;
float4x4 mmd_v   : VIEW;
float2 viewportSize : VIEWPORTPIXELSIZE;
static float2 halfpixel = (float2(0.5, 0.5) / viewportSize);
float3 light_direction : DIRECTION < string Object = "Light"; >;
float4 camera_position : POSITION < string Object = "Camera"; >;

// MMD MATERIAL
float4 material_diffuse : DIFFUSE < string Object  = "Geometry"; >;
float4 material_ambient : AMBIENT < string Object  = "Geometry"; >;
float4 material_emissive : EMISSIVE < string Object = "Geometry"; >;
float4 material_specular : SPECULAR < string Object = "Geometry"; >;
float specular_power     : SPECULARPOWER < string Object = "Geometry";>;
float3 light_ambient : AMBIENT < string Object  = "Light"; >;
float3 materialToon : TOONCOLOR;
float3 light_diffuse : DIFFUSE < string Object  = "Light"; >;
float3 light_specualr : SPECULAR < string Object = "Light"; >;
static float4 model_diffuse = material_diffuse * float4(light_diffuse, 1.0f);
static float4 model_ambient = saturate(material_ambient * float4(light_ambient, 1.0f) + material_emissive);
static float3 model_specular = material_specular.xyz * light_specualr;
static float4 model_color = saturate(model_ambient + model_diffuse); // this final model color will be multiplied by the diffuse texture

// mmd bools 
bool use_texture;
bool use_spheremap;
bool use_subtexture;
bool spadd; 

texture2D diffuse_texture : MATERIALTEXTURE;
texture2D sphere_texture : MATERIALSPHEREMAP;
texture2D toon_texture   : MATERIALTOONTEXTURE;

sampler2D diffuse_sampler = sampler_state
{
    texture = <diffuse_texture>;
    FILTER = ANISOTROPIC;
    ADDRESSV = WRAP;
    ADDRESSU = WRAP;
};

sampler2D sphere_sampler = sampler_state
{
    texture = <sphere_texture>;
    FILTER = ANISOTROPIC;
    ADDRESSV = WRAP;
    ADDRESSU = WRAP;
};

sampler2D toon_sampler = sampler_state
{
    texture = <toon_texture>;
    FILTER = ANISOTROPIC;
    ADDRESSV = CLAMP;
    ADDRESSU = CLAMP;
};


texture2D face_shadow_tex : OFFSCREENRENDERTARGET
<
    string Description = "Generate face shadow for projection";
    float2 ViewPortRatio = {1.0f, 1.0f};
    float4 ClearColor = {0.0f, 0.0f, 0.0f, 1.0f};
    float ClearDepth = 1.0f;
	bool AntiAlias = false;
	int Miplevels = 0;
	string DefaultEffect =
	    // "self=hide;"
	    "self=render_shadow.fx;";
>;

sampler2D face_shadow_sampler = sampler_state
{
    texture = <face_shadow_tex>;
    FILTER = ANISOTROPIC;
    ADDRESSV = CLAMP;
    ADDRESSU = CLAMP;
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
    float3 view : TEXCOORD2;
    float4 wpos : TEXCOORD3;

};

vs_out vs_shadow(vs_in i)
{
    vs_out o;
    o.pos = mul(i.pos, mmd_wvp);
    o.normal = mul(i.normal, (float3x3)mmd_w);
    o.uv = i.uv;
    o.view = camera_position.xyz - mul(i.pos.xyz, (float3x3)mmd_w);
    o.wpos = o.pos;
    return o;
}

float4 ps_shadow(vs_out i) : COLOR0
{
    float3 normal = normalize(i.normal);
    float3 view   = normalize(i.view);
    float4 color = model_color;

    float2 uv = i.uv;

    // construct screenspace uvs
    float2 ss_uv = i.wpos.xy / i.wpos.w;
    ss_uv.y = ss_uv.y * -1.0f;
    ss_uv.xy = (ss_uv.xy + 1.0f) * 0.5f + halfpixel;

    // construct sphere mapping coords
    float2 map;
    map = mul(normal, (float3x3)mmd_v);
    map.x = (map.x / 2.0f) + 0.5f; 
    map.y = (map.y / 2.0f) + 0.5f;
    // add the 0.5f bias to set the zero-distortion point at the center of the sphere
    map.y = -map.y; // invert the y axis to correct flipped image
    if(use_subtexture) map = uv; 

    // half lambert for ramp coords 
    float ndotl = dot(normal, -light_direction);
    ndotl = saturate(min(ndotl, 1.0f) * 0.5f + 0.5f);

    float shadow_tex = tex2D(face_shadow_sampler, ss_uv);

    // use projected shadow texture instead of models normals
    #ifdef use_projected_shadow
    ndotl = shadow_tex;
    #endif

    // specular 
    float3 half_vector = normalize(view + -light_direction);
    float ndoth = dot(normal, half_vector);
    ndoth = pow(max(ndoth, 0.001f), specular_power);
    float4 specular = (float4)0.0f;
    specular.xyz = ndoth * model_specular;


    // sample textures
    float4 diffuse = tex2D(diffuse_sampler, uv);
    float4 sphere  = tex2D(sphere_sampler, map);
    float4 toon    = tex2D(toon_sampler, float2(0.5f, 1.0f - ndotl)); // mmd toons are sampled from top to bottom so the y needs to be inverted
    
    color = (use_texture) ?  color * diffuse + specular : color * diffuse;
    color.xyz = (use_spheremap) ? ((spadd) ? color.xyz + sphere.xyz : color.xyz * sphere.xyz) : color.xyz;
    color.xyz = color.xyz * toon.xyz;


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
