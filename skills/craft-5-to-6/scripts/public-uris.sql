-- All live entry URIs, one per line, for snapshot.sh.
-- The homepage comes out as __home__.
--   mysql -N db < public-uris.sql > uris.txt
-- Add routes that don't belong to an entry (config/routes.php, plain
-- templates, a path that should 404) to the file by hand.
SELECT es.uri
FROM elements_sites es
JOIN elements el ON el.id = es.elementId
WHERE es.uri IS NOT NULL
  AND el.enabled = 1 AND es.enabled = 1
  AND el.draftId IS NULL AND el.revisionId IS NULL AND el.dateDeleted IS NULL
  AND el.type LIKE '%Entry'
ORDER BY es.uri;
