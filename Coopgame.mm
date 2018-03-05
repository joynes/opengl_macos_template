#import <Cocoa/Cocoa.h>
#import <OpenGL/OpenGL.h>
#import <OpenGL/gl3.h>

#include <string>
using namespace std;

#define  LOGI(...)  printf(__VA_ARGS__)
const unsigned WIDTH = 1024;
const unsigned HEIGHT = 1024;

void setup();

static GLuint spriteShader;

static const char vert_shad[] =
R"(
attribute vec4 pos;
void main() {
  gl_Position = pos;
}
)";

static const char frag_shad[] =
R"(
void main() {
  gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
}
)";

void drawSprites() {
  glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
}

void drawFrame() {
  glViewport(0, 0, (int) WIDTH, HEIGHT);
  glClearColor(1.0, 0.0, 1.0, 1.0);
  glClear(GL_COLOR_BUFFER_BIT);
  drawSprites();
  glFlush();
}

static void checkGlError(const char* op) {
  string str_error;
  for (GLenum error = glGetError(); error; error = glGetError()) {
    switch(error) {
      case GL_NO_ERROR: str_error = "GL_NO_ERROR";break;
      case GL_INVALID_ENUM: str_error = "GL_INVALID_ENUM";break;
      case GL_INVALID_VALUE: str_error = "GL_INVALID_VALUE";break;
      case GL_INVALID_OPERATION: str_error = "GL_INVALID_OPERATION";break;
      case GL_INVALID_FRAMEBUFFER_OPERATION: str_error = "GL_INVALID_FRAMEBUFFER_OPERATION";break;
      case GL_OUT_OF_MEMORY: str_error = "GL_OUT_OF_MEMORY";break;
      default: str_error = "unknown";
    }
      NSLog(@"after %s glError %s\n", op, str_error.c_str());
    }
}

GLuint LoadShader(GLenum type, const char *shaderSrc) {
  GLuint shader;
  GLint compiled;

  shader = glCreateShader(type);
  if (shader == 0) return 0;

  glShaderSource(shader, 1, &shaderSrc, NULL);
  glCompileShader(shader);

  glGetShaderiv(shader, GL_COMPILE_STATUS, &compiled);

  if (!compiled) {
    GLint infoLen = 0;
    glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &infoLen);
    if (infoLen > 1) {
      char *infoLog = static_cast<char *>(malloc(sizeof(char) * static_cast<unsigned long>(infoLen)));

      glGetShaderInfoLog(shader, infoLen, NULL, infoLog);
      LOGI("Error compiling %s\n\n%s", infoLog, shaderSrc);
      free(infoLog);
    }
    glDeleteShader(shader);
    exit(0);
  }
  return shader;
}

void checkLinkError(GLint linked, GLuint programId, const char *vertexshader, const char *fragmentShader) {
  if(!linked) {
    GLint infoLen = 0;
    glGetProgramiv(programId, GL_INFO_LOG_LENGTH, &infoLen);
    if(infoLen > 1) {
      char* infoLog = static_cast<char *>(malloc(sizeof(char) * static_cast<unsigned long>(infoLen)));
      glGetProgramInfoLog(programId, infoLen, NULL, infoLog);
      LOGI("Error linking program:\n%s\n", infoLog);
      free(infoLog);
    }
    glDeleteProgram(GLuint(linked));
    LOGI("Error when linking:\n %s\n\n\n%s", vertexshader, fragmentShader);
    exit(2);
  }
}

GLuint loadProgram(const char *vertexShader, const char *fragmentShader) {
  GLuint vs, fs;
  vs = LoadShader(GL_VERTEX_SHADER, vertexShader);
  fs = LoadShader(GL_FRAGMENT_SHADER, fragmentShader);

  GLuint programId = glCreateProgram();
  glAttachShader(programId, vs);
  checkGlError("Attach vertex shader");
  glAttachShader(programId, fs);
  checkGlError("Attach fragment shader");
  glLinkProgram(programId);

  GLint linked = GL_FALSE;
  glGetProgramiv(programId, GL_LINK_STATUS, &linked);
  checkLinkError(linked, programId, vertexShader, fragmentShader);
  return programId;
}

void setup() {
  const char *glsl_header = "";
  const char *vertex_header = glsl_header;

  const unsigned QUAD_VERTICE_SIZE = 2;
  const unsigned QUAD_TEX_SIZE = 2;
  const unsigned VERTICES = 4;
  static GLfloat vertices[] = {
    -1.0,  -1.0, // vertex coord
    0.0,  1.0, // texel coord, not used
    1.0,  -1.0,
    1.0,  1.0,
    1.0, 1.0,
    1.0,  0.0,
    -1.0, 1.0,
    0.0, 0.0
  };
  GLuint vbuffer;
  glGenBuffers(1, &vbuffer);

  glBindBuffer(GL_ARRAY_BUFFER, vbuffer);
  glBufferData(GL_ARRAY_BUFFER, VERTICES * (QUAD_TEX_SIZE + QUAD_TEX_SIZE) * sizeof(GLfloat), vertices, GL_STATIC_DRAW); 
  checkGlError("bind buffer");

  spriteShader = loadProgram(vert_shad, frag_shad);
  GLuint position = glGetAttribLocation(spriteShader, "pos");
  GLint comp = 2;
  GLsizei stride = 2;
  glVertexAttribPointer(position, comp, GL_FLOAT, GL_FALSE, (comp + stride)*sizeof(GLfloat), 0);
  glEnableVertexAttribArray(position);
  glUseProgram(spriteShader);
}

@interface GameView: NSOpenGLView {
  CVDisplayLinkRef displayLink;
}
@end

@implementation GameView
- (void)prepareOpenGL {
  
  // Synchronize buffer swaps with vertical refresh rate
  GLint swapInt = 1;
  [[self openGLContext] setValues:&swapInt forParameter:NSOpenGLCPSwapInterval];

  // Create a display link capable of being used with all active displays
  CVDisplayLinkCreateWithActiveCGDisplays(&displayLink);

  // Set the renderer output callback function
  CVDisplayLinkSetOutputCallback(displayLink, &DisplayLinkCallback, self);

  // Set the display link for the current renderer
  CGLContextObj cglContext = [[self openGLContext] CGLContextObj];
  CGLPixelFormatObj cglPixelFormat = static_cast<CGLPixelFormatObj>([self createPixelFormat]);
  CVDisplayLinkSetCurrentCGDisplayFromOpenGLContext(displayLink, cglContext, cglPixelFormat);

  // Activate the display link
  CVDisplayLinkStart(displayLink);
  setup();
}

- (NSOpenGLPixelFormat*)createPixelFormat
{
  NSOpenGLPixelFormat *pixelFormat;

  NSOpenGLPixelFormatAttribute attribs[] =
  {
    NSOpenGLPFANoRecovery,
    NSOpenGLPFAAccelerated,
    NSOpenGLPFADoubleBuffer,
    NSOpenGLPFAColorSize,        32,
    NSOpenGLPFAAlphaSize,        8,
    NSOpenGLPFAScreenMask,
    CGDisplayIDToOpenGLDisplayMask(kCGDirectMainDisplay),
    0
  };

  pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attribs];
  return [pixelFormat autorelease];
}

static CVReturn DisplayLinkCallback(CVDisplayLinkRef displayLink, const CVTimeStamp* now, const CVTimeStamp* outputTime,
CVOptionFlags flagsIn, CVOptionFlags* flagsOut, void* displayLinkContext)
{
    CVReturn result = [(GameView*)displayLinkContext getFrameForTime:outputTime];
    return result;
}

- (CVReturn)getFrameForTime:(const CVTimeStamp*)outputTime
{
    // Add your drawing codes here
  NSOpenGLContext *currentContext = [self openGLContext];
  [currentContext makeCurrentContext];

  // must lock GL context because display link is threaded
  CGLLockContext(static_cast<CGLContextObj>([currentContext CGLContextObj]));
  // Add your drawing codes here
  drawFrame();

  [currentContext flushBuffer];

  CGLUnlockContext(static_cast<CGLContextObj>([currentContext CGLContextObj]));
  return kCVReturnSuccess;
}

- (void)dealloc
{
    // Release the display link
    CVDisplayLinkRelease(displayLink);
    [super dealloc];
}
@end

int main() {
  [NSAutoreleasePool new];
  [NSApplication sharedApplication];
  [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

  id window = [[[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, WIDTH, HEIGHT) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO] autorelease];
  [window setTitle:@"Game"];
  [window makeKeyAndOrderFront:nil];
  [NSApp activateIgnoringOtherApps:YES];

  GameView *view = [[GameView alloc] initWithFrame:NSMakeRect(0, 0, WIDTH, HEIGHT)];
  [view setWantsLayer:YES];
  [[window contentView] addSubview:view];
  [NSApp run];
}
