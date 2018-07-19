#ifndef _HITLIB_H
#define _HITLIB_H

#define SETS_DESC_SET_ID 1
const uint MAX_TEXTURES = 64, MAX_SAMPLERS = 16;


// textrue/sampler set
layout ( binding = 0, set = SETS_DESC_SET_ID ) uniform texture2D textures[MAX_TEXTURES];
layout ( binding = 1, set = SETS_DESC_SET_ID ) uniform sampler samplers[MAX_SAMPLERS];

// material set (in main descriptor set)
layout ( std430, binding = 2, set = SETS_DESC_SET_ID ) readonly buffer VT_MATERIAL_BUFFER { VtAppMaterial submats[]; };
layout ( std430, binding = 3, set = SETS_DESC_SET_ID ) readonly buffer VT_COMBINED { uvec2 vtexures[]; };

layout ( std430, binding = 4, set = SETS_DESC_SET_ID ) readonly buffer VT_MATERIAL_INFO {
    uint materialCount;
    uint materialOffset;
};


int matID = -1;
#define material submats[matID]



// validate texture object
bool validateTexture(const uint tbinding) {
    int _binding = int(tbinding)-1;
    return _binding >= 0;
}

//#define vSampler2D(m) sampler2D(textures[vtexures[nonuniformEXT(m)].x], samplers[vtexures[nonuniformEXT(m)].y]) // reserved
#define vSampler2D(m) sampler2D(textures[vtexures[m].x], samplers[vtexures[m].y])
#define fetchTexture(tbinding, tcoord) textureLod(vSampler2D(tbinding-1), tcoord, 0)
#define fetchTextureOffset(tbinding, tcoord, toffset) textureLodOffset(vSampler2D(tbinding-1), tcoord, 0, toffset)


vec4 fetchDiffuse(in vec2 texcoord) {
    const uint tbinding = material.diffuseTexture;
    const vec4 rslt = validateTexture(tbinding) ? fetchTexture(tbinding, texcoord) : material.diffuse;
    return rslt;
}

vec4 fetchSpecular(in vec2 texcoord) {
    const uint tbinding = material.specularTexture;
    const vec4 rslt = validateTexture(tbinding) ? fetchTexture(tbinding, texcoord) : material.specular;
    return rslt;
}

vec4 fetchEmission(in vec2 texcoord) {
    const uint tbinding = material.emissiveTexture;
    const vec4 rslt = validateTexture(tbinding) ? fetchTexture(tbinding, texcoord) : material.emissive;
    return rslt;
}










#ifdef ENABLE_POM
const float parallaxScale = 0.02f;
const float minLayers = 10, maxLayers = 20;
const int refLayers = 10;
vec2 parallaxMapping(in vec3 V, in vec2 T, out float parallaxHeight) {
    const uint tbinding = material.bumpTexture;

    float numLayers = mix(maxLayers, minLayers, abs(dot(vec3(0, 0, 1), V)));
    float layerHeight = 1.0f / numLayers;
    vec2 dtex = parallaxScale * V.xy / V.z * layerHeight;
    vec3 chv = vec3(-dtex, layerHeight);
    
    // start pos
    vec3 chd_a = vec3(T, 0.f), chd_b = chd_a;

    // parallax sample tracing 
    for(int l=0;l<256;l++) {
        float heightFromTexture = 1.f-fetchTexture(tbinding, chd_b.xy).z;
        if ( heightFromTexture <= chd_b.z ) break;
        chd_a = chd_b, chd_b += chv;
    }
    
    // refinement
    [[unroll]]
    for(int l=0;l<refLayers;l++) {
        vec3 chd = mix(chd_a, chd_b, 0.5f);
        float heightFromTexture = 1.f-fetchTexture(tbinding, chd.xy).z;
        if ( heightFromTexture <= chd.z ) { chd_b = chd; } else { chd_a = chd; }
    }

    // do occlusion
    float nextH	= (1.f-fetchTexture(tbinding, chd_b.xy).z) - chd_b.z;
    float prevH = (1.f-fetchTexture(tbinding, chd_a.xy).z) - chd_a.z;

    float dvh = (nextH - prevH);
    float weight = nextH / precIssue(dvh);
    
    parallaxHeight = chd_b.z+mix(nextH, prevH, weight);
    return mix(chd_b.xy, chd_a.xy, weight);
}
#endif


// generated normal mapping
vec3 getUVH(in vec2 texcoord) { return vec3(texcoord, fetchTexture(material.bumpTexture, texcoord).x); }
vec3 getNormalMapping(in vec2 texcoordi) {
    const uint tbinding = material.bumpTexture;
    const vec3 tc = validateTexture(tbinding) ? fetchTexture(tbinding, texcoordi).xyz : vec3(0.5f, 0.5f, 1.0f);

    vec3 normal = vec3(0.f,0.f,1.f);
    IF (equalF(tc.x, tc.y) & equalF(tc.x, tc.z)) {
        //vec2 txs = 1.f/textureSize(sampler2D(textures[tbinding], samplers[0]), 0);
        vec2 txs = 1.f/textureSize(textures[tbinding], 0);
        vec4 tx4 = vec4(-txs.xy, txs.xy)*0.5f;
        vec4 txu = vec4(-1.f,-1.f,1.f,1.f)*0.5f;

        const float hsize = 4.f;
        vec3 t00 = vec3(txu.xy, getUVH(texcoordi + tx4.xy).z) * vec3(1.f, 1.f, hsize);
        vec3 t01 = vec3(txu.xw, getUVH(texcoordi + tx4.xw).z) * vec3(1.f, 1.f, hsize);
        vec3 t10 = vec3(txu.zy, getUVH(texcoordi + tx4.zy).z) * vec3(1.f, 1.f, hsize);
        vec3 bump = normalize(cross( t01 - t00, t10 - t00 ));
        normal = faceforward(bump, -bump, normal);
    } else {
        normal = normalize(fmix(vec3(0.0f, 0.0f, 1.0f), fma(tc, vec3(2.0f), vec3(-1.0f)), vec3(1.0f))), normal.y *= -1.f;
    }

    return normal;
}


#endif