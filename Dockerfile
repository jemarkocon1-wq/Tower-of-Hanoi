FROM swipl:9.2.9
ENV LANG=C.UTF-8
WORKDIR /app
COPY TOH.pl .
# Render sets the PORT environment variable; TOH.pl reads it.
CMD ["swipl", "-q", "-s", "TOH.pl"]
