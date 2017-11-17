# Samvera::NestingIndexer

[![Build Status](https://travis-ci.org/samvera-labs/samvera-nesting_indexer.png?branch=master)](https://travis-ci.org/samvera-labs/samvera-nesting_indexer)
[![Test Coverage](https://codeclimate.com/github/samvera-labs/samvera-nesting_indexer/badges/coverage.svg)](https://codeclimate.com/github/samvera-labs/samvera-nesting_indexer)
[![Code Climate](https://codeclimate.com/github/samvera-labs/samvera-nesting_indexer.png)](https://codeclimate.com/github/samvera-labs/samvera-nesting_indexer)
[![Documentation Status](http://inch-ci.org/github/samvera-labs/samvera-nesting_indexer.svg?branch=master)](http://inch-ci.org/github/samvera-labs/samvera-nesting_indexer)
[![APACHE 2 License](http://img.shields.io/badge/APACHE2-license-blue.svg)](./LICENSE)

The Samvera::NestingIndexer gem is responsible for indexing the graph relationship of objects. It maps a PreservationDocument to an IndexDocument by mapping a PreservationDocument's direct parents into the paths to get from a root document to the given PreservationDocument.

* [Background](#background)
* [Concepts](#concepts)
* [Examples](#examples)
* [Adapters](#adapters)
* [Considerations](#considerations)

## Background

This is a sandbox to work through the reindexing strategy as it relates to [CurateND Collections](https://github.com/ndlib/samvera_nd/issues/420). At this point the code is separate to allow for raid testing and prototyping (no sense spinning up SOLR and Fedora to walk an arbitrary graph).

### Notation

When B is a member of A, I am using the `A ={ B` notation. When C is a member of B and B is a member of A, I'll chain these together `A ={ B ={ C`.

## Concepts

As we are indexing objects, we have two types of documents:

1. [PreservationDocument](./lib/samvera/nesting_indexer/documents.rb) - a light-weight representation of a Fedora object
2. [IndexDocument](./lib/samvera/nesting_indexer/documents.rb) - a light-weight representation of a SOLR document object

We have four attributes to consider for indexing the graph:

1. id - the unique identifier for a document
2. parent_ids - the ids for all of the parents of a given document
3. pathnames - the paths to traverse from a root document to the given document
4. ancestors - the pathnames of each of the ancestors

See [Samvera::NestingIndexer::Documents::IndexDocument](./lib/samvera/nesting_indexer/documents.rb) for further discussion.

To reindex a single document, we leverage the [`Samvera::NestingIndexer.reindex_relationships`](./lib/samvera/nesting_indexer.rb) method.

## Examples

Given the following PreservationDocuments:

| PID | Parents |
|-----|---------|
| A   | -       |
| B   | -       |
| C   | A       |
| D   | A, B    |
| E   | C       |

If we were to reindex the above PreservationDocuments, we will generate the following IndexDocuments:

| PID | Parents | Pathnames  | Ancestors |
|-----|---------|------------|-----------|
| A   | -       | [A]        | []        |
| B   | -       | [B]        | []        |
| C   | A       | [A/C]      | [A]       |
| D   | A, B    | [A/D, B/D] | [A, B]    |
| E   | C       | [A/C/E]    | [A/C]     |

For more scenarios, look at the [Reindex PID and Descendants specs](./spec/features/reindex_id_and_descendants_spec.rb).

## Adapters

An [AbstractAdapter](./lib/samvera/nesting_indexer/adapters/abstract_adapter.rb) provides the method interface for others to build against.

The [InMemory adapter](./lib/samvera/nesting_indexer/adapters/in_memory_adapter.rb) is a reference implementation (and used to ease testing overhead).

CurateND has implemented the [following adapter](https://github.com/ndlib/samvera_nd/blob/master/lib/samvera/library_collection_indexing_adapter.rb) for its LibraryCollection indexing.

To define the adapter for your application:

```ruby
# In an application initializer (e.g. config/samvera_indexer_config.rb)
Samvera::NestingIndexer.configure do |config|
  config.adapter = MyCustomAdapter
end
```

To best ensure you have implemented the adapter to spec:

```ruby
# In the spec for MyCustomAdapter
require 'samvera/nesting_indexer/adapters/interface_behavior_spec'
RSpec.describe MyCustomAdapter
  it_behaves_like 'a Samvera::NestingIndexer::Adapter'
end
```

[See CurateND for Notre Dame's adaptor configuration](https://github.com/ndlib/samvera_nd/blob/6fbe79c9725c0f8b4641981044ec250c5163053b/config/initializers/samvera_config.rb#L32-L35).

## Considerations

Given a single object A, when we reindex A, we:

* Find the parent objects of A to calculate the ancestors and pathnames
* Iterate through each descendant, in a breadth-first process, to reindex it (and each descendant's descendants).

This is a potentially time consumptive process and should not be run within the request cycle.

### Cycle Detections

When dealing with nested graphs, there is a danger of creating an cycle (e.g. `A ={ B ={ A`). Samvera::NestingIndexer implements two guards to short-circuit the indexing of cyclic graphs:

* Enforcing a maximum nesting depth of the graph
* Checking that an object is not its own ancestor (`Samvera::NestingIndexer::RelationshipReindexer#guard_against_possiblity_of_self_ancestry`)

The [`./spec/features/reindex_pid_and_descendants_spec.rb`](spec/features/reindex_pid_and_descendants_spec.rb) contains examples of behavior.

**NOTE: These guards to prevent indexing cyclic graphs do not prevent the underlying preservation document from creating its own cyclic graph.**
