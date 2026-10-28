// Package views owns HTTP representations for this JSON MVC API.
package views

import "github.com/gin-gonic/gin"

func JSON(c *gin.Context, status int, value any)       { c.JSON(status, value) }
func Error(c *gin.Context, status int, detail string)  { c.JSON(status, gin.H{"detail": detail}) }
func Upstream(c *gin.Context, status int, body []byte) { c.Data(status, "application/json", body) }
