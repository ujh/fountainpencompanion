import * as React from "react";

const InkTable = ({entries, stats}) => <div className="table-responsive">
  <table className="table table-striped ink-collection">
    <Header entries={entries} />
    <Body entries={entries} />
    <Footer {...stats} />
  </table>
</div>;

const Header = ({entries}) => <thead>
  <tr>
    <th></th>
    <th>Brand</th>
    <th>Line</th>
    <th>Name</th>
    <th>Type</th>
    <th>Color</th>
    <th>Swabbed</th>
    <th>Used</th>
    <th>Comment</th>
    <th>Actions</th>
  </tr>
</thead>;

const Body = ({entries}) => <tbody>{ entries.map(entry => <Row {...entry.attributes} key={entry.id}/>) }</tbody>;

const Row = (props) => <tr className={`${props.private ? "private" : ""}`}>
  <td><i className={`fa fa-${props.private ? "lock" : "unlock"}`}></i></td>
  <td>{props.brand_name}</td>
  <td>{props.line_name}</td>
  <td>{props.ink_name}</td>
  <td>{props.kind}</td>
  <td style={{backgroundColor: props.color}}></td>
  <td className={`swabbed ${props.swabbed}`}><i className={`fa fa-${props.swabbed ? "check" : "times"}`}></i></td>
  <td className={`used ${props.used}`}><i className={`fa fa-${props.used ? "check" : "times"}`}></i></td>
  <td>{props.comment}</td>
  <td>
    <span className="actions">
      <a className="btn btn-default"><i className="fa fa-archive" /></a>
      {props.deletable ? <a className="btn btn-default"><i className="fa fa-trash" /></a> : null }
    </span>
  </td>
</tr>;

const Footer = ({brands, inks, bottles, samples, cartridges}) => <tfoot>
  <tr>
    <th></th>
    <th>{brands} brands</th>
    <th></th>
    <th>{inks} inks</th>
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
  </tr>
</tfoot>;

export default InkTable;
