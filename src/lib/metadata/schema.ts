import { Field, Fields, FieldInput, String, IPFSFile, parseFields, FieldTypes } from './fields';
import { View, ViewInput, DisplayView, parseViews } from './views';

type ViewsThunk = (fields: Fields) => View[];

type SchemaParameters = SimpleSchemaParameters | FullSchemaParameters;
type SimpleSchemaParameters = FieldTypes;
type FullSchemaParameters = { fields: FieldTypes; views?: View[] | ViewsThunk };

function isFullSchemaParameters(params: SchemaParameters): params is FullSchemaParameters {
  return (params as FullSchemaParameters).fields !== undefined;
}

export class Schema {
  fields: Fields;
  views: View[];

  public static create(params: SchemaParameters) {
    if (isFullSchemaParameters(params)) {
      const fields = Schema.prepareFields(params.fields);
      const views = Schema.prepareViews(fields, params.views ?? []);
      return new Schema(fields, views);
    }

    const fields = Schema.prepareFields(params);
    return new Schema(fields, []);
  }

  private constructor(fields: Fields, views: View[]) {
    this.fields = fields;
    this.views = views;
  }

  private static prepareFields(fieldTypes: FieldTypes): Fields {
    const fields = {};

    for (const name in fieldTypes) {
      fields[name] = new Field(name, fieldTypes[name]);
    }

    return fields;
  }

  getFieldList(): Field[] {
    return Object.values(this.fields);
  }

  private static prepareViews(fields: Fields, views: View[] | ViewsThunk): View[] {
    return Array.isArray(views) ? views : views(fields);
  }

  // TODO: include options in extend
  extend(schema: Schema | FieldTypes) {
    let fields: Fields;

    if (schema instanceof Schema) {
      fields = schema.fields;
    } else {
      fields = Schema.prepareFields(schema);
    }

    const newFields = Object.assign({}, this.fields, fields);

    return new Schema(newFields, this.views);
  }

  getView(viewType: new (...a: any) => View): View | undefined {
    return this.views.find((view: View) => view instanceof viewType);
  }

  export(): SchemaInput {
    const fields = this.getFieldList();

    return {
      fields: fields.map((field) => field.export()),
      views: this.views.map((view) => view.export()),
    };
  }
}

export function createSchema(params: SchemaParameters): Schema {
  return Schema.create(params);
}

export type SchemaInput = { fields: FieldInput[]; views?: ViewInput[] } | FieldInput[];

export function parseSchema(input: SchemaInput): Schema {
  if (Array.isArray(input)) {
    return createSchema({ fields: parseFields(input) });
  }

  return createSchema({
    fields: parseFields(input.fields),
    views: input.views ? parseViews(input.views) : [],
  });
}

export const defaultSchema = createSchema({
  fields: {
    name: String(),
    description: String(),
    thumbnail: IPFSFile(),
  },
  views: (fields: Fields) => [
    DisplayView({
      name: fields.name,
      description: fields.description,
      thumbnail: fields.thumbnail,
    }),
  ],
});
