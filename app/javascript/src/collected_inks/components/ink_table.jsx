import * as React from "react";

import NewEntry from "./new_entry";
import Row from "./row";

const InkTable = ({newEntryForm, entries, stats}) => <div className="table-responsive">
  <table className="table table-striped ink-collection">
    <Header entries={entries} />
    <Body entries={entries} />
    <Footer {...stats} newEntryForm={newEntryForm} />
  </table>
</div>;

const Header = ({entries}) => <thead>
  <tr>
    <th></th>
    <th>Brand</th>
    <th>Line</th>
    <th>Name</th>
    <th>Maker</th>
    <th>Type</th>
    <th>Color</th>
    <th>Swabbed</th>
    <th>Used</th>
    <th>Usage</th>
    <th>Comment</th>
    <th>Actions</th>
  </tr>
</thead>;

const Body = ({entries}) => <tbody>
  { entries.map(entry => <Row {...entry.attributes} id={entry.id} key={entry.id}/>) }
</tbody>;

const Footer = ({brands, inks, bottles, samples, cartridges, newEntryForm}) => <tfoot>
  {newEntryForm ? <NewEntry /> : null }
  <tr>
    <th></th>
    <th>{brands} brands</th>
    <th></th>
    <th>{inks} inks</th>
    <th></th>
    <th>
      {bottles}x bottle
      <br />
      {samples}x sample
      <br />
      {cartridges}x cartridge
    </th>
    <th></th>
    <th></th>
    <th></th>
    <th></th>
    <th></th>
    <th></th>
  </tr>
</tfoot>;

export default InkTable;
