#version 330

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;
in vec3 fragPosition;
in vec3 fragNormal;
in vec3 fragViewDir;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Output fragment color
out vec4 finalColor;

#define     MAX_LIGHTS              4
#define     LIGHT_DIRECTIONAL       0
#define     LIGHT_POINT             1

//struct Light {
//    int enabled;
//    int type;
//    vec3 position;
//    vec3 target;
//    vec4 color;
//};

// Input lighting values
//uniform Light lights[MAX_LIGHTS];
//uniform vec4 ambient;
//uniform vec3 viewPos;

void main () {
    vec4 ambient = vec4(0.4, 0.4, 0.6, 1.0);
    vec4 tex = texture(texture0, fragTexCoord);
    vec3 normal = normalize(fragNormal);
    vec3 view = normalize(fragViewDir);
    vec3 light = normalize(vec3(0, .5, 0.8));
    float ndotl = dot(normal, light);

    float ndotv = dot(normal, view);

    if (ndotl > .25) {
        finalColor = tex;
    } else {
        if (ndotv > 0.4) {
            finalColor = tex * ambient;
        } else {
            finalColor = vec4(vec3(tex) * vec3(0.5, 0.65, 0.65), 1.0);
        }
    }
}