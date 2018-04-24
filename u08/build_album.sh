#!/bin/bash
echo "<html><body>"
for img in *.jpg; do
    base=${img%.jpg}
    echo "<a href=\"${base}.jpg\"><img src=\"thumbs/${base}.thumb.jpg\"></a>"
done
echo "</body></html>"
