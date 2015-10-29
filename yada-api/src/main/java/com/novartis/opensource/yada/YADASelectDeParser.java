package com.novartis.opensource.yada;

import net.sf.jsqlparser.schema.Column;
import net.sf.jsqlparser.statement.select.SelectExpressionItem;
import net.sf.jsqlparser.util.deparser.SelectDeParser;

/**
 * A subclass of {@link net.sf.jsqlparser.util.deparser.SelectDeParser} with methods to account for JDBC-related columns and 
 * query-parsing-state management (i.e., flag setting/resetting)
 * @author David Varon
 *
 */
public class YADASelectDeParser extends SelectDeParser {

	/**
	 * Flog to mark when expression is aliased
	 */
	private boolean expressionHasAlias = false;
	/**
	 * Flog to mark when expression contains a jdbc parameter symbol
	 */
	private boolean hasJdbcParameter   = false;
	
	/**
	 * Default no-arg constructor
	 */
	public YADASelectDeParser() {}
	
	/**
	 * Creates a new instance, as well as sets vars for arguments.
	 * @param yadaExpressionDeParser the object for processing SQL expressions
	 * @param buffer the container for expression processing metadata
	 */
	public YADASelectDeParser(YADAExpressionDeParser yadaExpressionDeParser,
			StringBuffer buffer) {
		super(yadaExpressionDeParser,buffer);
	}

	/**
	 * Sets flags as needed, then calls handler.
	 * @see net.sf.jsqlparser.util.deparser.SelectDeParser#visit(net.sf.jsqlparser.statement.select.SelectExpressionItem)
	 */
	@Override
	public void visit(SelectExpressionItem selectExpressionItem) {
		super.visit(selectExpressionItem);
		this.expressionHasAlias = selectExpressionItem.getAlias() != null;
		YADAExpressionDeParser expDeParser = (YADAExpressionDeParser)this.getExpressionVisitor(); 
		this.hasJdbcParameter   = expDeParser.hasJdbcParameter();
		((YADAExpressionDeParser)this.getExpressionVisitor()).setInExpression(true);
		handleSelectExpressionItem(selectExpressionItem);
	}
	
	/**
	 * If the column in the expression has an alias and an associated JDBC parameter, the column is added to the 
	 * appropriate index, flags are subsequently reset.
	 * @param selectExpressionItem the select expression object to process
	 */
	public void handleSelectExpressionItem(SelectExpressionItem selectExpressionItem)
	{
		if(this.expressionHasAlias && this.hasJdbcParameter)
		{
			Column columnFromAlias = new Column();
			columnFromAlias.setColumnName(selectExpressionItem.getAlias());
			((YADAExpressionDeParser)this.getExpressionVisitor()).getJdbcColumns().add(columnFromAlias);
			resetInExpression();
			resetHasJdbcParameter();
			resetExpressionHasAlias();
		}
	}
	
	/**
	 * Resets flag to false after processing an item.
	 */
	public void resetInExpression()
	{
		((YADAExpressionDeParser)this.getExpressionVisitor()).setInExpression(false);	
	}
	
	/**
	 * Resets flag to false after processing an item.
	 */
	public void resetExpressionHasAlias() 
	{
		this.expressionHasAlias = false;
	}
	
	/**
	 * Resets flag to false after processing an item.
	 */
	public void resetHasJdbcParameter()
	{
		((YADAExpressionDeParser)this.getExpressionVisitor()).setHasJdbcParameter(false);
		this.hasJdbcParameter = false;
	}
}
