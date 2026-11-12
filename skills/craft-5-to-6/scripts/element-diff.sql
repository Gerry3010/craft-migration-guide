-- Per-element comparison between the upgraded database and a pre-upgrade copy.
--
-- Import the pre-upgrade dump into a second database named `baseline` on the
-- same server (DDEV: `ddev import-db --database=baseline --file=...`), then run
-- this as a user that can read both, from inside the upgraded database:
--   ddev mysql -uroot -proot db < element-diff.sql
--
-- Empty result sets mean: no canonical element lost, none changed.

-- Canonical elements whose title, slug, URI, field content or status changed
SELECT 'changed' k, b.elementId, b.siteId,
       LEFT(b.title, 40) old_title, LEFT(n.title, 40) new_title,
       b.content <=> n.content same_content,
       b.slug <=> n.slug same_slug,
       b.uri <=> n.uri same_uri
FROM baseline.elements_sites b
JOIN elements_sites n ON n.elementId = b.elementId AND n.siteId = b.siteId
JOIN baseline.elements be ON be.id = b.elementId
WHERE be.dateDeleted IS NULL AND be.draftId IS NULL AND be.revisionId IS NULL
  AND NOT (b.title <=> n.title AND b.slug <=> n.slug AND b.uri <=> n.uri
           AND b.content <=> n.content AND b.enabled <=> n.enabled);

-- Element-site rows that exist in the baseline but not anymore
SELECT 'missing' k, b.elementId, b.siteId, LEFT(b.title, 40) title
FROM baseline.elements_sites b
JOIN baseline.elements be ON be.id = b.elementId
LEFT JOIN elements_sites n ON n.elementId = b.elementId AND n.siteId = b.siteId
WHERE be.dateDeleted IS NULL AND n.id IS NULL;

-- Relations that disappeared, with the field they belonged to.
-- After Craft 6 expect the rows of Link fields here, nothing else.
SELECT 'relation-missing' k, r.id, f.handle field, f.type field_type,
       r.sourceId, se.revisionId IS NOT NULL source_is_revision, r.targetId
FROM baseline.relations r
LEFT JOIN relations n ON n.id = r.id
JOIN baseline.fields f ON f.id = r.fieldId
JOIN baseline.elements se ON se.id = r.sourceId
WHERE n.id IS NULL;
