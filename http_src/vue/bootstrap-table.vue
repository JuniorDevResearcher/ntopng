<!--
    (C) 2013-22 - ntop.org
    word-break:break-all;
-->
<template>
  <!-- Normal table -->
  <table v-if="!(horizontal) || (horizontal == false)" class="table table-striped table-bordered col-sm-12" style="">
    <thead>
      <tr>
        <th v-for="col in columns" scope="col" :class="col.class" v-html="print_html_column(col)"></th>
      </tr>
    </thead>
    <tbody>
      <tr v-for="row in rows" class="">	
        <td v-if="wrap_columns == true" v-for="col in columns" scope="col" style="height:2.5rem;" :class="col.class">
	  <div class="wrap-column" v-html="print_html_row(col, row)"></div>
	</td>
        <td v-else v-for="col in columns" scope="col" :class="col.class" class="wrap_column" v-html="print_html_row(col, row)">
	</td>
      </tr>
    </tbody>
  </table>
  <!-- Horizontal table, with th on the rows -->
  <table v-else class="table table-striped table-bordered">
    <tbody>
      <tr v-for="row in rows ">
        <th class="col 5" v-html="print_html_title(row.name)"></th>
        <td :colspan="[(row.values.length <= 1) ? 2 : 1]" v-for="value in row.values" v-html="print_html_row(value)">
        </td>
      </tr>
    </tbody>
  </table>
</template>

<script setup>

const props = defineProps({
  id: String,
  columns: Array,
  rows: Array,
  print_html_column: Function,
  print_html_row: Function,
  print_html_title: Function,
  horizontal: Boolean,
  wrap_columns: Boolean,
});

</script>

<style scoped>
.wrap-column {
  text-overflow: ellipsis;
  white-space: nowrap;
  overflow: hidden;
  max-width:100%;
}
</style>
