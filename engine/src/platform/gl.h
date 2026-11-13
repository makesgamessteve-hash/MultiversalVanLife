/* Multiversal Van Life - OpenGL 3.3 core / OpenGL ES 3.0 (WebGL2) access.
 * On desktop all entry points are loaded at runtime through SDL so the
 * executable does not link against a specific GL library. MIT License. */
#ifndef MVL_GL_H
#define MVL_GL_H

#ifdef __EMSCRIPTEN__
#include <GLES3/gl3.h>
#define MVL_GLSL_HEADER "#version 300 es\nprecision highp float;\nprecision highp int;\n"
#else
#include <SDL3/SDL_opengl.h>
#define MVL_GLSL_HEADER "#version 330 core\n"

/* X(return type, name, parameter list) */
#define MVL_GL_FUNCS                                                                                   \
    X(void, glClear, (GLbitfield))                                                                     \
    X(void, glClearColor, (GLfloat, GLfloat, GLfloat, GLfloat))                                        \
    X(void, glViewport, (GLint, GLint, GLsizei, GLsizei))                                              \
    X(void, glScissor, (GLint, GLint, GLsizei, GLsizei))                                               \
    X(void, glEnable, (GLenum))                                                                        \
    X(void, glDisable, (GLenum))                                                                       \
    X(void, glBlendFunc, (GLenum, GLenum))                                                             \
    X(void, glDepthFunc, (GLenum))                                                                     \
    X(void, glDepthMask, (GLboolean))                                                                  \
    X(void, glCullFace, (GLenum))                                                                      \
    X(void, glStencilFunc, (GLenum, GLint, GLuint))                                                    \
    X(void, glStencilOp, (GLenum, GLenum, GLenum))                                                     \
    X(void, glStencilMask, (GLuint))                                                                   \
    X(void, glClearStencil, (GLint))                                                                   \
    X(void, glColorMask, (GLboolean, GLboolean, GLboolean, GLboolean))                                 \
    X(void, glPolygonOffset, (GLfloat, GLfloat))                                                       \
    X(void, glGenTextures, (GLsizei, GLuint *))                                                        \
    X(void, glDeleteTextures, (GLsizei, const GLuint *))                                               \
    X(void, glBindTexture, (GLenum, GLuint))                                                           \
    X(void, glTexImage2D, (GLenum, GLint, GLint, GLsizei, GLsizei, GLint, GLenum, GLenum, const void *)) \
    X(void, glTexParameteri, (GLenum, GLenum, GLint))                                                  \
    X(void, glDrawArrays, (GLenum, GLint, GLsizei))                                                    \
    X(void, glReadPixels, (GLint, GLint, GLsizei, GLsizei, GLenum, GLenum, void *))                    \
    X(void, glPixelStorei, (GLenum, GLint))                                                            \
    X(void, glGetIntegerv, (GLenum, GLint *))                                                          \
    X(GLenum, glGetError, (void))                                                                      \
    X(const GLubyte *, glGetString, (GLenum))                                                          \
    X(void, glActiveTexture, (GLenum))                                                                 \
    X(GLuint, glCreateShader, (GLenum))                                                                \
    X(void, glShaderSource, (GLuint, GLsizei, const GLchar *const *, const GLint *))                   \
    X(void, glCompileShader, (GLuint))                                                                 \
    X(void, glGetShaderiv, (GLuint, GLenum, GLint *))                                                  \
    X(void, glGetShaderInfoLog, (GLuint, GLsizei, GLsizei *, GLchar *))                                \
    X(void, glDeleteShader, (GLuint))                                                                  \
    X(GLuint, glCreateProgram, (void))                                                                 \
    X(void, glAttachShader, (GLuint, GLuint))                                                          \
    X(void, glBindAttribLocation, (GLuint, GLuint, const GLchar *))                                    \
    X(void, glLinkProgram, (GLuint))                                                                   \
    X(void, glGetProgramiv, (GLuint, GLenum, GLint *))                                                 \
    X(void, glGetProgramInfoLog, (GLuint, GLsizei, GLsizei *, GLchar *))                               \
    X(void, glDeleteProgram, (GLuint))                                                                 \
    X(void, glUseProgram, (GLuint))                                                                    \
    X(GLint, glGetUniformLocation, (GLuint, const GLchar *))                                           \
    X(void, glUniform1i, (GLint, GLint))                                                               \
    X(void, glUniform1f, (GLint, GLfloat))                                                             \
    X(void, glUniform2f, (GLint, GLfloat, GLfloat))                                                    \
    X(void, glUniform3f, (GLint, GLfloat, GLfloat, GLfloat))                                           \
    X(void, glUniform4f, (GLint, GLfloat, GLfloat, GLfloat, GLfloat))                                  \
    X(void, glUniform3fv, (GLint, GLsizei, const GLfloat *))                                           \
    X(void, glUniform1fv, (GLint, GLsizei, const GLfloat *))                                           \
    X(void, glUniformMatrix4fv, (GLint, GLsizei, GLboolean, const GLfloat *))                          \
    X(void, glGenVertexArrays, (GLsizei, GLuint *))                                                    \
    X(void, glBindVertexArray, (GLuint))                                                               \
    X(void, glDeleteVertexArrays, (GLsizei, const GLuint *))                                           \
    X(void, glGenBuffers, (GLsizei, GLuint *))                                                         \
    X(void, glBindBuffer, (GLenum, GLuint))                                                            \
    X(void, glBufferData, (GLenum, GLsizeiptr, const void *, GLenum))                                  \
    X(void, glDeleteBuffers, (GLsizei, const GLuint *))                                                \
    X(void, glVertexAttribPointer, (GLuint, GLint, GLenum, GLboolean, GLsizei, const void *))          \
    X(void, glEnableVertexAttribArray, (GLuint))                                                       \
    X(void, glGenFramebuffers, (GLsizei, GLuint *))                                                    \
    X(void, glBindFramebuffer, (GLenum, GLuint))                                                       \
    X(void, glFramebufferTexture2D, (GLenum, GLenum, GLenum, GLuint, GLint))                           \
    X(void, glDeleteFramebuffers, (GLsizei, const GLuint *))                                           \
    X(GLenum, glCheckFramebufferStatus, (GLenum))                                                      \
    X(void, glGenRenderbuffers, (GLsizei, GLuint *))                                                   \
    X(void, glBindRenderbuffer, (GLenum, GLuint))                                                      \
    X(void, glRenderbufferStorage, (GLenum, GLenum, GLsizei, GLsizei))                                 \
    X(void, glFramebufferRenderbuffer, (GLenum, GLenum, GLenum, GLuint))                               \
    X(void, glDeleteRenderbuffers, (GLsizei, const GLuint *))

#define X(ret, name, params) typedef ret(APIENTRY *mvl_pfn_##name) params; extern mvl_pfn_##name mvl_##name;
MVL_GL_FUNCS
#undef X

#define glClear mvl_glClear
#define glClearColor mvl_glClearColor
#define glViewport mvl_glViewport
#define glScissor mvl_glScissor
#define glEnable mvl_glEnable
#define glDisable mvl_glDisable
#define glBlendFunc mvl_glBlendFunc
#define glDepthFunc mvl_glDepthFunc
#define glDepthMask mvl_glDepthMask
#define glCullFace mvl_glCullFace
#define glStencilFunc mvl_glStencilFunc
#define glStencilOp mvl_glStencilOp
#define glStencilMask mvl_glStencilMask
#define glClearStencil mvl_glClearStencil
#define glColorMask mvl_glColorMask
#define glPolygonOffset mvl_glPolygonOffset
#define glGenTextures mvl_glGenTextures
#define glDeleteTextures mvl_glDeleteTextures
#define glBindTexture mvl_glBindTexture
#define glTexImage2D mvl_glTexImage2D
#define glTexParameteri mvl_glTexParameteri
#define glDrawArrays mvl_glDrawArrays
#define glReadPixels mvl_glReadPixels
#define glPixelStorei mvl_glPixelStorei
#define glGetIntegerv mvl_glGetIntegerv
#define glGetError mvl_glGetError
#define glGetString mvl_glGetString
#define glActiveTexture mvl_glActiveTexture
#define glCreateShader mvl_glCreateShader
#define glShaderSource mvl_glShaderSource
#define glCompileShader mvl_glCompileShader
#define glGetShaderiv mvl_glGetShaderiv
#define glGetShaderInfoLog mvl_glGetShaderInfoLog
#define glDeleteShader mvl_glDeleteShader
#define glCreateProgram mvl_glCreateProgram
#define glAttachShader mvl_glAttachShader
#define glBindAttribLocation mvl_glBindAttribLocation
#define glLinkProgram mvl_glLinkProgram
#define glGetProgramiv mvl_glGetProgramiv
#define glGetProgramInfoLog mvl_glGetProgramInfoLog
#define glDeleteProgram mvl_glDeleteProgram
#define glUseProgram mvl_glUseProgram
#define glGetUniformLocation mvl_glGetUniformLocation
#define glUniform1i mvl_glUniform1i
#define glUniform1f mvl_glUniform1f
#define glUniform2f mvl_glUniform2f
#define glUniform3f mvl_glUniform3f
#define glUniform4f mvl_glUniform4f
#define glUniform3fv mvl_glUniform3fv
#define glUniform1fv mvl_glUniform1fv
#define glUniformMatrix4fv mvl_glUniformMatrix4fv
#define glGenVertexArrays mvl_glGenVertexArrays
#define glBindVertexArray mvl_glBindVertexArray
#define glDeleteVertexArrays mvl_glDeleteVertexArrays
#define glGenBuffers mvl_glGenBuffers
#define glBindBuffer mvl_glBindBuffer
#define glBufferData mvl_glBufferData
#define glDeleteBuffers mvl_glDeleteBuffers
#define glVertexAttribPointer mvl_glVertexAttribPointer
#define glEnableVertexAttribArray mvl_glEnableVertexAttribArray
#define glGenFramebuffers mvl_glGenFramebuffers
#define glBindFramebuffer mvl_glBindFramebuffer
#define glFramebufferTexture2D mvl_glFramebufferTexture2D
#define glDeleteFramebuffers mvl_glDeleteFramebuffers
#define glCheckFramebufferStatus mvl_glCheckFramebufferStatus
#define glGenRenderbuffers mvl_glGenRenderbuffers
#define glBindRenderbuffer mvl_glBindRenderbuffer
#define glRenderbufferStorage mvl_glRenderbufferStorage
#define glFramebufferRenderbuffer mvl_glFramebufferRenderbuffer
#define glDeleteRenderbuffers mvl_glDeleteRenderbuffers
#endif

/* Loads all entry points (no-op on the web). Returns 1 on success. */
int mvl_gl_load(void);

#endif
