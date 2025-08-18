<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:atom="http://www.w3.org/2005/Atom">
  <xsl:output method="html" encoding="UTF-8"/>
  <xsl:template match="/">
    <html>
      <head>
        <title><xsl:value-of select="/rss/channel/title"/></title>
        <style>
          body { font-family: Arial, sans-serif; margin: 20px; }
          h1 { color: #333; }
          .feed-item { margin-bottom: 20px; }
          .feed-item h2 { margin: 0; font-size: 1.5em; }
          .feed-item a { color: #0066cc; text-decoration: none; }
          .feed-item a:hover { text-decoration: underline; }
          .feed-item p { color: #555; }
        </style>
      </head>
      <body>
        <h1><xsl:value-of select="/rss/channel/title"/></h1>
        <p><xsl:value-of select="/rss/channel/description"/></p>
        <p><a href="{/rss/channel/link}">Visit the site</a></p>
        <h2>Recent Posts</h2>
        <xsl:for-each select="/rss/channel/item">
          <div class="feed-item">
            <h2><a href="{link}"><xsl:value-of select="title"/></a></h2>
            <p><strong>Published:</strong> <xsl:value-of select="pubDate"/></p>
            <p><xsl:value-of select="description" disable-output-escaping="yes"/></p>
          </div>
        </xsl:for-each>
      </body>
    </html>
  </xsl:template>
</xsl:stylesheet>